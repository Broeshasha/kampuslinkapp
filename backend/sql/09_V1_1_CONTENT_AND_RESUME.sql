-- =============================================================================
-- KAMPUSLINK BACKEND  |  09  V1.1: CONTENT BLOCKS, RESUME, OFFLINE SYNC
-- =============================================================================
-- Run AFTER 01-06. Re-runnable. Paste the whole file, or part by part.
-- WHY (found while reading your sample chapter JSON and designing the app):
--   1. lessons are structured BLOCKS (paragraph, table, figure, equation...), not markdown
--   2. a chapter groups several lessons (episodes)                       -> unit columns
--   3. nothing may reach students without a rights decision and a review -> publish gate
--   4. "continue where I stopped" needs a saved reading position         -> new table + RPCs
--   5. offline actions must be replayable without double counting        -> sync_progress()
--   6. a chat message sent twice (bad network) must appear once          -> client_id
--   7. the offline download must be small: only the languages the student needs
--                                                                        -> get_module_bundle(module, langs)
-- After this file: run file 10 (tests).
-- =============================================================================


-- =============================================================================
-- PART 1  LESSON CONTENT: blocks per language + chapter (unit) info + rights
-- =============================================================================
alter table public.learn_lesson_i18n add column if not exists blocks jsonb not null default '[]'::jsonb;

alter table public.learn_lessons add column if not exists chapter_ref       text;      -- e.g. 'chapter_02'
alter table public.learn_lessons add column if not exists unit_number       smallint;  -- chapter number
alter table public.learn_lessons add column if not exists unit_title        jsonb not null default '{}'::jsonb;   -- {"en":..,"fr":..,"ar":..}
alter table public.learn_lessons add column if not exists estimated_minutes smallint;
alter table public.learn_lessons add column if not exists rights_status     text not null default 'unknown';

alter table public.learn_lessons drop constraint if exists learn_lessons_rights_check;
alter table public.learn_lessons add  constraint learn_lessons_rights_check
  check (rights_status in ('unknown','permission_granted','public_domain','own_work'));
alter table public.learn_lessons drop constraint if exists learn_lessons_minutes_check;
alter table public.learn_lessons add  constraint learn_lessons_minutes_check
  check (estimated_minutes is null or estimated_minutes between 1 and 120);

-- glossary entries carry a trilingual definition (the sample chapter has 32 of them)
alter table public.module_glossary add column if not exists definition jsonb;   -- {"en":..,"fr":..,"ar":..}

-- PUBLISH GATE: a lesson cannot be 'published' while it needs review or its rights are unknown.
create or replace function public.trg_publish_gate()
returns trigger language plpgsql as $$
begin
  if new.status = 'published' then
    if new.needs_review then
      raise exception 'publish_blocked: lesson still needs review';
    end if;
    if new.rights_status = 'unknown' then
      raise exception 'publish_blocked: rights_status is unknown';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_publish_gate on public.learn_lessons;
create trigger trg_publish_gate
  before insert or update of status, needs_review, rights_status on public.learn_lessons
  for each row execute function public.trg_publish_gate();
revoke all on function public.trg_publish_gate() from public, anon, authenticated;

-- the offline JSON also changes when blocks change
drop trigger if exists trg_bump_version on public.learn_lesson_i18n;
create trigger trg_bump_version after insert or update or delete on public.learn_lesson_i18n
  for each row execute function public.trg_bump_module_version();


-- =============================================================================
-- PART 2  READING POSITION ("where I stopped")
-- =============================================================================
create table if not exists public.learn_reading_position (
  user_id    uuid   not null references public.profiles(id)      on delete cascade,
  lesson_id  bigint not null references public.learn_lessons(id) on delete cascade,
  block_id   text,
  progress   real   not null default 0 check (progress >= 0 and progress <= 1),
  updated_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);
create index if not exists learn_reading_position_recent_idx
  on public.learn_reading_position (user_id, updated_at desc);

alter table public.learn_reading_position enable row level security;
drop policy if exists "reading position own read" on public.learn_reading_position;
create policy "reading position own read" on public.learn_reading_position
  for select to authenticated using (user_id = auth.uid());
revoke all on public.learn_reading_position from anon, authenticated;
grant select on public.learn_reading_position to authenticated;

-- block ids are the same in every language, so the position survives a language switch.
-- The latest timestamp wins (an old offline write never overwrites newer reading).
create or replace function public.save_reading_position(
  p_lesson   bigint,
  p_block_id text,
  p_progress real,
  p_at       timestamptz default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  mid bigint;
  ts  timestamptz := least(coalesce(p_at, now()), now());
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select l.module_id into mid from public.learn_lessons l
   where l.id = p_lesson and l.status = 'published';
  if mid is null or not public.user_in_module(mid) then raise exception 'not_available'; end if;

  insert into public.learn_reading_position (user_id, lesson_id, block_id, progress, updated_at)
  values (uid, p_lesson, left(p_block_id, 80), least(greatest(coalesce(p_progress, 0), 0), 1), ts)
  on conflict (user_id, lesson_id) do update
    set block_id   = excluded.block_id,
        progress   = excluded.progress,
        updated_at = excluded.updated_at
    where public.learn_reading_position.updated_at <= excluded.updated_at;
end $$;

-- lessons the student started and has not finished, most recent first (Home "Continue")
create or replace function public.get_continue_items(p_limit integer default 5)
returns table (
  lesson_id   bigint,
  module_id   bigint,
  module_name text,
  title       text,
  progress    real,
  block_id    text,
  updated_at  timestamptz
)
language sql stable security definer set search_path = public as $$
  select l.id, l.module_id, m.name,
         (select i.title from public.learn_lesson_i18n i
           where i.lesson_id = l.id
           order by (i.lang = coalesce((select p.preferred_language from public.profiles p
                                         where p.id = auth.uid()), 'en')) desc,
                    (i.lang = 'fr') desc, i.lang
           limit 1),
         rp.progress, rp.block_id, rp.updated_at
  from public.learn_reading_position rp
  join public.learn_lessons l on l.id = rp.lesson_id and l.status = 'published'
  join public.study_modules m on m.id = l.module_id
  where rp.user_id = auth.uid()
    and rp.progress < 0.98
    and not exists (select 1 from public.learn_lesson_progress lp
                     where lp.user_id = auth.uid() and lp.lesson_id = l.id)
    and l.module_id in (select public.my_module_ids())
  order by rp.updated_at desc
  limit least(greatest(coalesce(p_limit, 5), 1), 20)
$$;


-- =============================================================================
-- PART 3  OFFLINE SYNC: replayable operations (each op_id is applied at most once)
-- =============================================================================
create table if not exists public.client_ops (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  op_id      uuid not null,
  kind       text not null,
  status     text not null default 'applied' check (status in ('applied','rejected')),
  message    text,
  created_at timestamptz not null default now(),
  primary key (user_id, op_id)
);
create index if not exists client_ops_created_idx on public.client_ops (created_at);
alter table public.client_ops enable row level security;      -- no policy: functions only
revoke all on public.client_ops from anon, authenticated;
-- housekeeping (run monthly, or schedule with pg_cron):
--   delete from public.client_ops where created_at < now() - interval '60 days';

-- p_ops = [{"op_id":"<uuid>","kind":"review","payload":{...}}, ...]   (max 200, applied in order)
--  kind            payload
--  review          {"card_id":1,"correct":true}
--  answer          {"question_id":1,"choice":0}
--  lesson_done     {"lesson_id":1,"score":80}
--  study_time      {"seconds":120}
--  reading_position{"lesson_id":1,"block_id":"sec_I_2_004","progress":0.4,"at":"2026-10-17T10:00:00Z"}
--  like | save     {"card_id":1,"on":true}
-- Returns one result per op: applied | duplicate | rejected (+ message).
create or replace function public.sync_progress(p_ops jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid     uuid := auth.uid();
  item    jsonb;
  v_id    uuid;
  v_kind  text;
  v_pl    jsonb;
  v_card  bigint;
  v_st    text;
  v_msg   text;
  results jsonb := '[]'::jsonb;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_ops is null or jsonb_typeof(p_ops) <> 'array' then raise exception 'invalid_ops'; end if;
  if jsonb_array_length(p_ops) > 200 then raise exception 'too_many_ops'; end if;

  for item in select e.value from jsonb_array_elements(p_ops) e loop
    begin
      v_id := (item ->> 'op_id')::uuid;
    exception when others then
      results := results || jsonb_build_object('op_id', item ->> 'op_id', 'status', 'rejected', 'message', 'invalid_op_id');
      continue;
    end;
    v_kind := item ->> 'kind';
    v_pl   := coalesce(item -> 'payload', '{}'::jsonb);

    if exists (select 1 from public.client_ops c where c.user_id = uid and c.op_id = v_id) then
      results := results || jsonb_build_object('op_id', v_id, 'status', 'duplicate');
      continue;
    end if;

    begin
      if v_kind = 'review' then
        perform public.review_card((v_pl ->> 'card_id')::bigint, (v_pl ->> 'correct')::boolean);
      elsif v_kind = 'answer' then
        perform public.submit_answer((v_pl ->> 'question_id')::bigint, (v_pl ->> 'choice')::integer);
      elsif v_kind = 'lesson_done' then
        perform public.complete_lesson((v_pl ->> 'lesson_id')::bigint, nullif(v_pl ->> 'score', '')::integer);
      elsif v_kind = 'study_time' then
        perform public.log_study_time((v_pl ->> 'seconds')::integer);
      elsif v_kind = 'reading_position' then
        perform public.save_reading_position((v_pl ->> 'lesson_id')::bigint, v_pl ->> 'block_id',
                                             (v_pl ->> 'progress')::real, nullif(v_pl ->> 'at', '')::timestamptz);
      elsif v_kind in ('like', 'save') then
        v_card := (v_pl ->> 'card_id')::bigint;
        if not exists (select 1 from public.learn_cards c
                         join public.learn_lessons l on l.id = c.lesson_id
                        where c.id = v_card and l.status = 'published' and public.user_in_module(l.module_id)) then
          raise exception 'card_not_available';
        end if;
        if v_kind = 'like' then
          if coalesce((v_pl ->> 'on')::boolean, true) then
            insert into public.learn_card_likes (card_id, user_id) values (v_card, uid) on conflict do nothing;
          else
            delete from public.learn_card_likes where card_id = v_card and user_id = uid;
          end if;
        else
          if coalesce((v_pl ->> 'on')::boolean, true) then
            insert into public.learn_card_saves (card_id, user_id) values (v_card, uid) on conflict do nothing;
          else
            delete from public.learn_card_saves where card_id = v_card and user_id = uid;
          end if;
        end if;
      else
        raise exception 'unknown_kind';
      end if;
      v_st := 'applied'; v_msg := null;
    exception when others then
      v_st := 'rejected'; v_msg := sqlerrm;
    end;

    insert into public.client_ops (user_id, op_id, kind, status, message)
    values (uid, v_id, left(coalesce(v_kind, '?'), 30), v_st, left(v_msg, 200));
    results := results || jsonb_build_object('op_id', v_id, 'status', v_st, 'message', v_msg);
  end loop;
  return results;
end $$;


-- =============================================================================
-- PART 4  CHAT: a message sent twice (retry on a bad network) is stored once
-- =============================================================================
alter table public.module_chat_messages add column if not exists client_id uuid;
create unique index if not exists module_chat_client_uidx
  on public.module_chat_messages (user_id, client_id) where client_id is not null;

drop function if exists public.post_chat_message(bigint, text, text, uuid, jsonb);
create or replace function public.post_chat_message(
  p_module    bigint,
  p_body      text,
  p_lang      text default 'und',
  p_reply_to  uuid default null,
  p_file      jsonb default null,
  p_client_id uuid default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid     uuid := auth.uid();
  v_body  text := left(trim(coalesce(p_body, '')), 4000);
  v_lang  text := coalesce(p_lang, 'und');
  v_reply uuid := p_reply_to;
  rid     bigint;
  mid     uuid;
  recent  integer;
  lim     integer;
begin
  perform public._assert_can_contribute();
  if not public.user_in_module(p_module) then raise exception 'not_in_module'; end if;

  -- retry of a message we already stored: return it, do not post again
  if p_client_id is not null then
    select m.id, m.resource_id into mid, rid
      from public.module_chat_messages m
     where m.user_id = uid and m.client_id = p_client_id;
    if mid is not null then
      return jsonb_build_object('message_id', mid, 'resource_id', rid, 'duplicate', true);
    end if;
  end if;

  if v_body = '' and p_file is null then raise exception 'empty_message'; end if;
  if v_lang not in ('ar','fr','en','und') then v_lang := 'und'; end if;

  select coalesce((select (c.value #>> '{}')::int from public.app_config c
                   where c.key = 'chat_rate_limit_per_minute'), 20) into lim;
  select count(*)::int into recent from public.module_chat_messages x
   where x.user_id = uid and x.created_at > now() - interval '1 minute';
  if recent >= lim then raise exception 'rate_limited'; end if;

  if v_reply is not null and not exists (
    select 1 from public.module_chat_messages x where x.id = v_reply and x.module_id = p_module
  ) then v_reply := null; end if;

  if p_file is not null then
    rid := public._register_file(p_module, uid, p_file, 'chat_upload');
  end if;

  insert into public.module_chat_messages (module_id, user_id, body, lang, reply_to, resource_id, client_id)
  values (p_module, uid, v_body, v_lang, v_reply, rid, p_client_id)
  returning id into mid;

  if rid is not null then
    update public.study_resources set source_message_id = coalesce(source_message_id, mid) where id = rid;
  end if;
  return jsonb_build_object('message_id', mid, 'resource_id', rid, 'duplicate', false);
end $$;


-- =============================================================================
-- PART 5  THE OFFLINE BUNDLE: now with blocks, units, glossary definitions and a language filter
--         get_module_bundle(module)                      -> all languages (as before)
--         get_module_bundle(module, array['fr','ar'])    -> only those languages (about 1/3 smaller per language)
-- =============================================================================
create or replace function public._filter_langs(j jsonb, langs text[])
returns jsonb language sql immutable as $$
  select case
           when j is null then null
           when langs is null then j
           else coalesce((select jsonb_object_agg(e.key, e.value)
                            from jsonb_each(j) e where e.key = any(langs)), '{}'::jsonb)
         end
$$;

drop function if exists public.get_module_bundle(bigint);
create or replace function public.get_module_bundle(p_module bigint, p_langs text[] default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.user_in_module(p_module) then raise exception 'not_in_module'; end if;
  if p_langs is not null and exists (select 1 from unnest(p_langs) x where x not in ('ar','fr','en')) then
    raise exception 'invalid_language';
  end if;
  return (
    select jsonb_build_object(
      'schema_version', 2,
      'module', jsonb_build_object('id', m.id, 'name', m.name, 'semester', m.semester,
                                   'ue_category', m.ue_category, 'academic_year', m.academic_year),
      'version', coalesce((select v.version from public.module_content_versions v
                           where v.module_id = m.id), 0),
      'languages', coalesce(to_jsonb(p_langs), '["ar","fr","en"]'::jsonb),
      'generated_at', now(),
      'lessons', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', l.id,
          'position', l.position,
          'source_lang', l.source_lang,
          'unit', jsonb_build_object('ref', l.chapter_ref, 'number', l.unit_number,
                                     'title', public._filter_langs(l.unit_title, p_langs)),
          'estimated_minutes', l.estimated_minutes,
          'source_pages', l.source_pages,
          'i18n', coalesce((
            select jsonb_object_agg(li.lang, jsonb_build_object(
              'title', li.title, 'summary', li.summary, 'body_md', li.body_md,
              'key_terms', li.key_terms, 'blocks', li.blocks))
            from public.learn_lesson_i18n li
            where li.lesson_id = l.id and (p_langs is null or li.lang = any(p_langs))), '{}'::jsonb),
          'cards', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', c.id, 'position', c.position,
              'i18n', coalesce((
                select jsonb_object_agg(ci.lang, jsonb_build_object('front', ci.front, 'back', ci.back))
                from public.learn_card_i18n ci
                where ci.card_id = c.id and (p_langs is null or ci.lang = any(p_langs))), '{}'::jsonb)
            ) order by c.position, c.id)
            from public.learn_cards c where c.lesson_id = l.id), '[]'::jsonb),
          'questions', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', q.id, 'kind', q.kind, 'correct_index', q.correct_index, 'position', q.position,
              'i18n', coalesce((
                select jsonb_object_agg(qi.lang, jsonb_build_object(
                  'prompt', qi.prompt, 'options', qi.options, 'explanation', qi.explanation))
                from public.learn_question_i18n qi
                where qi.question_id = q.id and (p_langs is null or qi.lang = any(p_langs))), '{}'::jsonb)
            ) order by q.position, q.id)
            from public.learn_questions q where q.lesson_id = l.id), '[]'::jsonb),
          'resources', coalesce((
            select jsonb_agg(jsonb_build_object('resource_id', lr.resource_id, 'role', lr.role))
            from public.learn_lesson_resources lr where lr.lesson_id = l.id), '[]'::jsonb)
        ) order by l.position, l.id)
        from public.learn_lessons l
        where l.module_id = m.id and l.status = 'published'), '[]'::jsonb),
      'resources', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', r.id, 'type', r.resource_type, 'format', r.file_format, 'title', r.title,
          'file_urls', r.file_urls, 'trust_label', r.trust_label, 'size_bytes', r.size_bytes,
          'origin', r.origin, 'created_at', r.created_at) order by r.created_at desc)
        from public.study_resources r where r.module_id = m.id and r.status = 'visible'), '[]'::jsonb),
      'glossary', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', g.id,
          'fr', case when p_langs is null or 'fr' = any(p_langs) then g.fr end,
          'ar', case when p_langs is null or 'ar' = any(p_langs) then g.ar end,
          'en', case when p_langs is null or 'en' = any(p_langs) then g.en end,
          'definition', public._filter_langs(g.definition, p_langs),
          'note', g.note) order by g.id)
        from public.module_glossary g where g.module_id = m.id), '[]'::jsonb)
    )
    from public.study_modules m
    where m.id = p_module
  );
end $$;


-- =============================================================================
-- PART 6  EXECUTE RIGHTS for everything new in this file
-- =============================================================================
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('save_reading_position','get_continue_items','sync_progress',
                        'post_chat_message','get_module_bundle')
  loop
    execute format('revoke all on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;

  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('_filter_langs')
  loop
    execute format('revoke all on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;
