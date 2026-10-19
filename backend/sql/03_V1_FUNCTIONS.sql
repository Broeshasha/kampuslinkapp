-- =============================================================================
-- KAMPUSLINK BACKEND  |  03  V1 FUNCTIONS (the only way the app WRITES)
-- =============================================================================
-- Run AFTER 02. Re-runnable (create or replace).
-- Every function checks auth.uid() itself. At the end, a block removes the default
-- public/anon execute rights and grants authenticated only (service-only functions to
-- service_role).
--
-- LIST
--   helpers   algiers_today, is_admin, my_module_ids, user_in_module
--   onboard   get_onboarding_options, complete_onboarding, set_language, get_me
--   modules   get_my_modules, get_module_bundle  (bundle = the offline JSON)
--   learning  get_home_cards, review_card, submit_answer, complete_lesson, log_study_time
--   chat      get_chat_messages, post_chat_message, delete_chat_message
--   files     add_module_resource, toggle_resource_upvote, register_download
--   social    toggle_card_like, toggle_card_save, add_card_comment, get_card_comments,
--             delete_card_comment
--   account   register_push_token, unregister_push_token, set_reminders, delete_my_account
--   service   due_reminders, mark_reminder_sent   (only the service role)
--   internal  _touch_activity, _register_file, _assert_can_contribute
-- =============================================================================


-- =============================================================================
-- HELPERS
-- =============================================================================
create or replace function public.algiers_today()
returns date language sql stable as $$
  select (now() at time zone 'Africa/Algiers')::date
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false)
$$;

-- the modules of the signed-in student: same speciality (or domain-wide), same year,
-- same university (or university not set on the module)
create or replace function public.my_module_ids()
returns setof bigint language sql stable security definer set search_path = public as $$
  select m.id
  from public.profiles p
  join public.specialities s on s.id = p.speciality_id
  join public.study_modules m
    on m.academic_year = p.academic_year
   and (m.speciality_id = p.speciality_id
        or (m.speciality_id is null and m.domain_id = s.domain_id))
   and (m.university_id is null or m.university_id = p.university_id)
  where p.id = auth.uid()
$$;

create or replace function public.user_in_module(p_module bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.my_module_ids() as t(id) where t.id = p_module)
$$;

-- writing (chat, comments, uploads) needs a signed-in user who finished onboarding
-- (Google sign-in is the identity; there is no extra verification step)
create or replace function public._assert_can_contribute()
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.profiles p
                  where p.id = auth.uid() and p.onboarding_complete) then
    raise exception 'onboarding_required';
  end if;
end $$;


-- =============================================================================
-- ACTIVITY: streak + xp + reminder reset (internal, called by the RPCs below)
-- =============================================================================
create or replace function public._touch_activity(p_user uuid, p_xp integer default 0)
returns void language plpgsql security definer set search_path = public as $$
declare
  today date := public.algiers_today();
  st    public.study_stats;
  streak integer;
begin
  insert into public.study_stats (user_id) values (p_user) on conflict (user_id) do nothing;
  select * into st from public.study_stats where user_id = p_user for update;

  streak := st.current_streak;
  if st.last_active_date is distinct from today then
    if st.last_active_date = today - 1 then streak := streak + 1; else streak := 1; end if;
  end if;

  update public.study_stats
     set xp = xp + greatest(coalesce(p_xp, 0), 0),
         current_streak = streak,
         longest_streak = greatest(longest_streak, streak),
         last_active_date = today
   where user_id = p_user;

  insert into public.user_reminder_state (user_id, last_active_at, step)
  values (p_user, now(), 0)
  on conflict (user_id) do update set last_active_at = now(), step = 0;
end $$;


-- =============================================================================
-- ONBOARDING AND PROFILE
-- =============================================================================
create or replace function public.get_onboarding_options()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'universities', coalesce((
      select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.name, 'city', u.city,
                                          'wilaya_id', u.wilaya_id) order by u.name)
      from public.universities u), '[]'::jsonb),
    'specialities', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'max_year', s.max_year,
                                          'year_system', s.year_system,
                                          'learn_enabled', s.learn_enabled) order by s.name)
      from public.specialities s), '[]'::jsonb)
  )
$$;

create or replace function public.set_language(p_lang text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_lang is null or p_lang not in ('ar','fr','en') then raise exception 'invalid_language'; end if;
  update public.profiles set preferred_language = p_lang where id = auth.uid();
end $$;

create or replace function public.get_me()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'username', p.username,
    'avatar_url', p.avatar_url,
    'avatar_blurhash', p.avatar_blurhash,
    'language', p.preferred_language,
    'university_id', p.university_id,
    'university_name', u.name,
    'university_city', u.city,
    'speciality_id', p.speciality_id,
    'speciality_name', s.name,
    'academic_year', p.academic_year,
    'section', p.section,
    'group_name', p.group_name,
    'study_goal_minutes', p.study_goal_minutes,
    'onboarding_complete', p.onboarding_complete,
    'onboarding_version', p.onboarding_version,
    'is_admin', p.is_admin,
    'xp', coalesce(st.xp, 0),
    'current_streak', case when st.last_active_date >= public.algiers_today() - 1
                           then st.current_streak else 0 end,
    'longest_streak', coalesce(st.longest_streak, 0),
    'today_seconds', coalesce((select d.active_seconds from public.study_daily d
                               where d.user_id = p.id and d.day = public.algiers_today()), 0),
    'reminders_enabled', coalesce((select not r.unsubscribed from public.user_reminder_state r
                                   where r.user_id = p.id), true)
  )
  from public.profiles p
  left join public.universities u on u.id = p.university_id
  left join public.specialities s on s.id = p.speciality_id
  left join public.study_stats st on st.user_id = p.id
  where p.id = auth.uid()
$$;

create or replace function public.complete_onboarding(
  p_username       text,
  p_university_id  integer,
  p_speciality_id  integer,
  p_academic_year  text,
  p_language       text default 'en',
  p_section        text default null,
  p_group          text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid   uuid := auth.uid();
  uname text := lower(trim(coalesce(p_username, '')));
  ysys  text;
  ymax  smallint;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if uname !~ '^[a-z0-9_.]{3,20}$' then raise exception 'invalid_username'; end if;
  if exists (select 1 from public.profiles x where lower(x.username) = uname and x.id <> uid) then
    raise exception 'username_taken';
  end if;
  if not exists (select 1 from public.universities where id = p_university_id) then
    raise exception 'invalid_university';
  end if;
  select s.year_system, s.max_year into ysys, ymax
    from public.specialities s where s.id = p_speciality_id;
  if ysys is null then raise exception 'invalid_speciality'; end if;
  if p_language is null or p_language not in ('ar','fr','en') then raise exception 'invalid_language'; end if;

  if ysys = 'unified' then
    if p_academic_year is null or p_academic_year !~ '^Year [1-6]$'
       or substring(p_academic_year from 6)::int > ymax then
      raise exception 'invalid_year';
    end if;
  else
    if p_academic_year is null or p_academic_year not in ('L1','L2','L3','M1','M2') then
      raise exception 'invalid_year';
    end if;
  end if;

  update public.profiles
     set username = uname,
         university_id = p_university_id,
         speciality_id = p_speciality_id,
         academic_year = p_academic_year,
         preferred_language = p_language,
         section    = nullif(left(trim(coalesce(p_section, '')), 20), ''),
         group_name = nullif(left(trim(coalesce(p_group,   '')), 20), ''),
         onboarding_complete = true,
         onboarding_version  = 1
   where id = uid;
  if not found then raise exception 'profile_missing'; end if;

  insert into public.study_stats (user_id) values (uid) on conflict (user_id) do nothing;
  insert into public.user_reminder_state (user_id, last_active_at) values (uid, now())
    on conflict (user_id) do nothing;
  return public.get_me();
end $$;


-- =============================================================================
-- MODULES AND THE OFFLINE BUNDLE
-- =============================================================================
create or replace function public.get_my_modules()
returns table (
  module_id     bigint,
  name          text,
  semester      smallint,
  ue_category   text,
  academic_year text,
  version       integer,
  lessons       integer,
  lessons_done  integer,
  resources     integer
)
language sql stable security definer set search_path = public as $$
  select m.id, m.name, m.semester, m.ue_category, m.academic_year,
         coalesce(v.version, 0),
         (select count(*)::int from public.learn_lessons l
           where l.module_id = m.id and l.status = 'published'),
         (select count(*)::int from public.learn_lesson_progress lp
            join public.learn_lessons l on l.id = lp.lesson_id
           where lp.user_id = auth.uid() and l.module_id = m.id and l.status = 'published'),
         (select count(*)::int from public.study_resources r
           where r.module_id = m.id and r.status = 'visible')
  from public.study_modules m
  left join public.module_content_versions v on v.module_id = m.id
  where m.id in (select public.my_module_ids())
  order by m.semester nulls last, m.name
$$;

-- the whole module as ONE json document: this is what the app stores offline
create or replace function public.get_module_bundle(p_module bigint)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.user_in_module(p_module) then raise exception 'not_in_module'; end if;
  return (
    select jsonb_build_object(
      'schema_version', 1,
      'module', jsonb_build_object('id', m.id, 'name', m.name, 'semester', m.semester,
                                   'ue_category', m.ue_category, 'academic_year', m.academic_year),
      'version', coalesce((select v.version from public.module_content_versions v
                           where v.module_id = m.id), 0),
      'generated_at', now(),
      'lessons', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', l.id,
          'position', l.position,
          'source_lang', l.source_lang,
          'i18n', coalesce((
            select jsonb_object_agg(li.lang, jsonb_build_object(
              'title', li.title, 'summary', li.summary,
              'body_md', li.body_md, 'key_terms', li.key_terms))
            from public.learn_lesson_i18n li where li.lesson_id = l.id), '{}'::jsonb),
          'cards', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', c.id, 'position', c.position,
              'i18n', coalesce((
                select jsonb_object_agg(ci.lang, jsonb_build_object('front', ci.front, 'back', ci.back))
                from public.learn_card_i18n ci where ci.card_id = c.id), '{}'::jsonb)
            ) order by c.position, c.id)
            from public.learn_cards c where c.lesson_id = l.id), '[]'::jsonb),
          'questions', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', q.id, 'kind', q.kind, 'correct_index', q.correct_index, 'position', q.position,
              'i18n', coalesce((
                select jsonb_object_agg(qi.lang, jsonb_build_object(
                  'prompt', qi.prompt, 'options', qi.options, 'explanation', qi.explanation))
                from public.learn_question_i18n qi where qi.question_id = q.id), '{}'::jsonb)
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
        select jsonb_agg(jsonb_build_object('fr', g.fr, 'ar', g.ar, 'en', g.en, 'note', g.note) order by g.id)
        from public.module_glossary g where g.module_id = m.id), '[]'::jsonb)
    )
    from public.study_modules m
    where m.id = p_module
  );
end $$;


-- =============================================================================
-- LEARNING: feed, reviews, quizzes, lessons, study time
-- =============================================================================
create or replace function public.get_home_cards(p_limit integer default 20)
returns table (
  card_id       bigint,
  lesson_id     bigint,
  module_id     bigint,
  module_name   text,
  front         text,
  back          text,
  box           integer,
  due_at        timestamptz,
  like_count    bigint,
  comment_count bigint,
  liked         boolean,
  saved         boolean
)
language sql stable security definer set search_path = public as $$
  with me as (
    select coalesce(p.preferred_language, 'en') as lang
    from public.profiles p where p.id = auth.uid()
  ),
  base as (
    select c.id as card_id, l.id as lesson_id, l.module_id, m.name as module_name
    from public.learn_cards c
    join public.learn_lessons l on l.id = c.lesson_id and l.status = 'published'
    join public.study_modules m on m.id = l.module_id
    where l.module_id in (select public.my_module_ids())
  )
  select b.card_id, b.lesson_id, b.module_id, b.module_name, t.front, t.back,
         coalesce(pr.box, 1)::int, pr.due_at,
         (select count(*) from public.learn_card_likes x where x.card_id = b.card_id),
         (select count(*) from public.learn_card_comments x
           where x.card_id = b.card_id and x.deleted_at is null),
         exists (select 1 from public.learn_card_likes x
                  where x.card_id = b.card_id and x.user_id = auth.uid()),
         exists (select 1 from public.learn_card_saves x
                  where x.card_id = b.card_id and x.user_id = auth.uid())
  from base b
  cross join me
  cross join lateral (
    select i.front, i.back
    from public.learn_card_i18n i
    where i.card_id = b.card_id
    order by (i.lang = me.lang) desc, (i.lang = 'fr') desc, (i.lang = 'en') desc, i.lang
    limit 1
  ) t
  left join public.learn_card_progress pr
         on pr.card_id = b.card_id and pr.user_id = auth.uid()
  order by (pr.due_at is not null and pr.due_at <= now()) desc,   -- due cards first
           (pr.card_id is null) desc,                              -- then new cards
           coalesce(pr.due_at, now()),                             -- then soonest due
           random()
  limit least(greatest(coalesce(p_limit, 20), 1), 100)
$$;

-- Leitner boxes 1..5: right = up one box, wrong = back to box 1
create or replace function public.review_card(p_card bigint, p_correct boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid    uuid := auth.uid();
  cur    public.learn_card_progress;
  newbox integer;
  wait   interval;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.learn_cards c
    join public.learn_lessons l on l.id = c.lesson_id
    where c.id = p_card and l.status = 'published' and public.user_in_module(l.module_id)
  ) then raise exception 'card_not_available'; end if;

  select * into cur from public.learn_card_progress
   where user_id = uid and card_id = p_card;

  newbox := case when p_correct then least(coalesce(cur.box, 1) + 1, 5) else 1 end;
  wait := case newbox
            when 1 then interval '10 minutes'
            when 2 then interval '1 day'
            when 3 then interval '3 days'
            when 4 then interval '7 days'
            else interval '14 days'
          end;

  insert into public.learn_card_progress (user_id, card_id, box, due_at, last_reviewed_at, reps, lapses)
  values (uid, p_card, newbox, now() + wait, now(), 1, case when p_correct then 0 else 1 end)
  on conflict (user_id, card_id) do update
    set box = excluded.box,
        due_at = excluded.due_at,
        last_reviewed_at = now(),
        reps = public.learn_card_progress.reps + 1,
        lapses = public.learn_card_progress.lapses + case when p_correct then 0 else 1 end;

  insert into public.study_daily (user_id, day, cards_reviewed)
  values (uid, public.algiers_today(), 1)
  on conflict (user_id, day) do update
    set cards_reviewed = public.study_daily.cards_reviewed + 1;

  perform public._touch_activity(uid, case when p_correct then 2 else 1 end);
  return jsonb_build_object('box', newbox, 'due_at', now() + wait);
end $$;

-- a wrong answer pulls the whole lesson's cards back to the top of the feed
create or replace function public.submit_answer(p_question bigint, p_choice integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  q   public.learn_questions;
  les public.learn_lessons;
  ok  boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into q from public.learn_questions where id = p_question;
  if q.id is null then raise exception 'question_not_found'; end if;
  select * into les from public.learn_lessons where id = q.lesson_id and status = 'published';
  if les.id is null or not public.user_in_module(les.module_id) then
    raise exception 'not_available';
  end if;

  ok := (p_choice = q.correct_index);
  insert into public.learn_quiz_attempts (user_id, lesson_id, question_id, chosen_index, is_correct)
  values (uid, les.id, q.id, p_choice, ok);

  if not ok then
    insert into public.learn_card_progress (user_id, card_id, box, due_at)
    select uid, c.id, 1, now() from public.learn_cards c where c.lesson_id = les.id
    on conflict (user_id, card_id) do update set box = 1, due_at = now();
  end if;

  perform public._touch_activity(uid, case when ok then 3 else 1 end);
  return jsonb_build_object('correct', ok, 'correct_index', q.correct_index);
end $$;

create or replace function public.complete_lesson(p_lesson bigint, p_score integer default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid  uuid := auth.uid();
  les  public.learn_lessons;
  first_time boolean;
  nxt  bigint;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into les from public.learn_lessons where id = p_lesson and status = 'published';
  if les.id is null or not public.user_in_module(les.module_id) then
    raise exception 'not_available';
  end if;

  first_time := not exists (select 1 from public.learn_lesson_progress
                             where user_id = uid and lesson_id = p_lesson);
  insert into public.learn_lesson_progress (user_id, lesson_id, score)
  values (uid, p_lesson, p_score)
  on conflict (user_id, lesson_id) do update
    set score = greatest(coalesce(public.learn_lesson_progress.score, 0), coalesce(excluded.score, 0));

  perform public._touch_activity(uid, case when first_time then 10 else 1 end);

  select l.id into nxt from public.learn_lessons l
   where l.module_id = les.module_id and l.status = 'published'
     and (l.position, l.id) > (les.position, les.id)
   order by l.position, l.id limit 1;
  return jsonb_build_object('first_time', first_time, 'next_lesson_id', nxt);
end $$;

-- the app calls this every ~30-60 s while the screen is active (max 15 min per call)
create or replace function public.log_study_time(p_seconds integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid   uuid := auth.uid();
  s     integer := least(greatest(coalesce(p_seconds, 0), 0), 900);
  today date := public.algiers_today();
  total integer;
  goal  integer;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select coalesce(p.study_goal_minutes, 30) * 60 into goal from public.profiles p where p.id = uid;

  if s > 0 then
    insert into public.study_daily (user_id, day, active_seconds)
    values (uid, today, s)
    on conflict (user_id, day) do update
      set active_seconds = public.study_daily.active_seconds + excluded.active_seconds
    returning active_seconds into total;
    if total >= 300 then perform public._touch_activity(uid, 0); end if;   -- 5 active minutes = streak day
  else
    select d.active_seconds into total from public.study_daily d where d.user_id = uid and d.day = today;
  end if;
  total := coalesce(total, 0);
  return jsonb_build_object('today_seconds', total, 'goal_seconds', goal, 'goal_reached', total >= goal);
end $$;


-- =============================================================================
-- FILES (internal helper + library upload + upvote + download counter)
-- =============================================================================
create or replace function public._register_file(p_module bigint, p_uid uuid, p_file jsonb, p_origin text)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  rid   bigint;
  furl  text := p_file ->> 'url';
  fhash text := nullif(p_file ->> 'hash', '');
  ftype text;
  ffmt  text;
  fsize bigint;
  base  text;
  maxmb integer;
begin
  if furl is null or furl = '' then raise exception 'invalid_file'; end if;

  -- only files our own upload worker produced (stops random links posing as documents)
  select c.value #>> '{}' into base from public.app_config c where c.key = 'files_base_url';
  if base is not null and left(furl, length(base)) <> base then raise exception 'invalid_file_url'; end if;

  ftype := coalesce(nullif(p_file ->> 'type', ''), 'notes');
  if ftype not in ('cours','td','tp','textbook','exercices_corriges','exam','notes','memoire','other') then
    ftype := 'notes';
  end if;
  ffmt := coalesce(nullif(p_file ->> 'format', ''), 'other');
  if ffmt not in ('pdf','image_set','doc','ppt','image','sheet','other') then ffmt := 'other'; end if;

  fsize := nullif(p_file ->> 'size', '')::bigint;
  select (c.value #>> '{}')::int into maxmb from public.app_config c where c.key = 'max_upload_mb';
  if fsize is not null and maxmb is not null and fsize > maxmb::bigint * 1024 * 1024 then
    raise exception 'file_too_large';
  end if;

  if fhash is not null then
    select r.id into rid from public.study_resources r
     where r.module_id = p_module and r.file_hash = fhash and r.status <> 'removed' limit 1;
    if rid is not null then return rid; end if;   -- same file already in this module
  end if;

  insert into public.study_resources
    (module_id, uploader_id, resource_type, trust_label, file_format, file_urls,
     title, file_hash, size_bytes, mime_type, origin, status)
  values
    (p_module, p_uid, ftype, 'Unverified', ffmt, jsonb_build_array(furl),
     left(p_file ->> 'title', 200), fhash, fsize, p_file ->> 'mime', p_origin, 'visible')
  on conflict (module_id, file_hash) where (file_hash is not null and status <> 'removed') do nothing
  returning id into rid;

  if rid is null and fhash is not null then   -- lost a race with an identical upload
    select r.id into rid from public.study_resources r
     where r.module_id = p_module and r.file_hash = fhash and r.status <> 'removed' limit 1;
  end if;
  return rid;
end $$;

create or replace function public.add_module_resource(p_module bigint, p_file jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare rid bigint;
begin
  perform public._assert_can_contribute();
  if not public.user_in_module(p_module) then raise exception 'not_in_module'; end if;
  rid := public._register_file(p_module, auth.uid(), p_file, 'library_upload');
  return jsonb_build_object('resource_id', rid);
end $$;

create or replace function public.toggle_resource_upvote(p_resource bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid  uuid := auth.uid();
  mid  bigint;
  n    integer;
  now_on boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select r.module_id into mid from public.study_resources r
   where r.id = p_resource and r.status = 'visible';
  if mid is null or not public.user_in_module(mid) then raise exception 'not_available'; end if;

  if exists (select 1 from public.study_resource_upvotes u where u.user_id = uid and u.resource_id = p_resource) then
    delete from public.study_resource_upvotes where user_id = uid and resource_id = p_resource;
    now_on := false;
  else
    insert into public.study_resource_upvotes (user_id, resource_id) values (uid, p_resource);
    now_on := true;
  end if;
  select count(*)::int into n from public.study_resource_upvotes where resource_id = p_resource;
  update public.study_resources set upvote_count = n where id = p_resource;
  return jsonb_build_object('upvoted', now_on, 'count', n);
end $$;

create or replace function public.register_download(p_resource bigint)
returns void language plpgsql security definer set search_path = public as $$
declare mid bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select r.module_id into mid from public.study_resources r where r.id = p_resource and r.status = 'visible';
  if mid is null or not public.user_in_module(mid) then raise exception 'not_available'; end if;
  update public.study_resources set download_count = download_count + 1 where id = p_resource;
end $$;


-- =============================================================================
-- MODULE CHAT
-- =============================================================================
create or replace function public.get_chat_messages(
  p_module bigint,
  p_before timestamptz default null,
  p_limit  integer default 50
)
returns table (
  id               uuid,
  module_id        bigint,
  user_id          uuid,
  username         text,
  avatar_url       text,
  avatar_blurhash  text,
  body             text,
  lang             text,
  translated_body  text,
  translated_lang  text,
  reply_to         uuid,
  resource_id      bigint,
  resource_title   text,
  resource_type    text,
  created_at       timestamptz,
  is_mine          boolean
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare mylang text;
begin
  if not public.user_in_module(p_module) then raise exception 'not_in_module'; end if;
  select coalesce(pp.preferred_language, 'en') into mylang
    from public.profiles pp where pp.id = auth.uid();

  return query
  select m.id, m.module_id, m.user_id, p.username, p.avatar_url, p.avatar_blurhash,
         m.body, m.lang, tr.body, tr.lang, m.reply_to, m.resource_id,
         r.title, r.resource_type, m.created_at, (m.user_id = auth.uid())
  from public.module_chat_messages m
  join public.profiles p on p.id = m.user_id
  left join public.message_translations tr
         on tr.message_id = m.id and tr.lang = mylang and m.lang <> mylang
  left join public.study_resources r on r.id = m.resource_id
  where m.module_id = p_module
    and m.deleted_at is null
    and (p_before is null or m.created_at < p_before)
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = m.user_id)
         or (b.blocker_id = m.user_id and b.blocked_id = auth.uid()))
  order by m.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
end $$;

-- p_file example: {"url":"https://files.kampus-link.com/files/..","hash":"..","size":123456,
--                  "mime":"application/pdf","title":"TD 3","type":"td","format":"pdf"}
-- A file sent in chat is also stored in the module Library (same row, no duplicate).
create or replace function public.post_chat_message(
  p_module   bigint,
  p_body     text,
  p_lang     text default 'und',
  p_reply_to uuid default null,
  p_file     jsonb default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid    uuid := auth.uid();
  v_body text := left(trim(coalesce(p_body, '')), 4000);
  v_lang text := coalesce(p_lang, 'und');
  v_reply uuid := p_reply_to;
  rid    bigint;
  mid    uuid;
  recent integer;
  lim    integer;
begin
  perform public._assert_can_contribute();
  if not public.user_in_module(p_module) then raise exception 'not_in_module'; end if;
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

  insert into public.module_chat_messages (module_id, user_id, body, lang, reply_to, resource_id)
  values (p_module, uid, v_body, v_lang, v_reply, rid)
  returning id into mid;

  if rid is not null then
    update public.study_resources set source_message_id = coalesce(source_message_id, mid) where id = rid;
  end if;
  return jsonb_build_object('message_id', mid, 'resource_id', rid);
end $$;

create or replace function public.delete_chat_message(p_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.module_chat_messages
     set deleted_at = now()
   where id = p_id and deleted_at is null
     and (user_id = auth.uid() or public.is_admin());
  return found;
end $$;


-- =============================================================================
-- FLASHCARD SOCIAL
-- =============================================================================
create or replace function public.toggle_card_like(p_card bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); n bigint; on_now boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.learn_cards c join public.learn_lessons l on l.id = c.lesson_id
                  where c.id = p_card and l.status = 'published' and public.user_in_module(l.module_id)) then
    raise exception 'card_not_available';
  end if;
  if exists (select 1 from public.learn_card_likes x where x.card_id = p_card and x.user_id = uid) then
    delete from public.learn_card_likes where card_id = p_card and user_id = uid; on_now := false;
  else
    insert into public.learn_card_likes (card_id, user_id) values (p_card, uid); on_now := true;
  end if;
  select count(*) into n from public.learn_card_likes where card_id = p_card;
  return jsonb_build_object('liked', on_now, 'count', n);
end $$;

create or replace function public.toggle_card_save(p_card bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); on_now boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.learn_cards c join public.learn_lessons l on l.id = c.lesson_id
                  where c.id = p_card and l.status = 'published' and public.user_in_module(l.module_id)) then
    raise exception 'card_not_available';
  end if;
  if exists (select 1 from public.learn_card_saves x where x.card_id = p_card and x.user_id = uid) then
    delete from public.learn_card_saves where card_id = p_card and user_id = uid; on_now := false;
  else
    insert into public.learn_card_saves (card_id, user_id) values (p_card, uid); on_now := true;
  end if;
  return jsonb_build_object('saved', on_now);
end $$;

create or replace function public.add_card_comment(p_card bigint, p_body text, p_parent uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_body text := left(trim(coalesce(p_body, '')), 500); cid uuid; recent integer;
begin
  perform public._assert_can_contribute();
  if v_body = '' then raise exception 'empty_comment'; end if;
  if not exists (select 1 from public.learn_cards c join public.learn_lessons l on l.id = c.lesson_id
                  where c.id = p_card and l.status = 'published' and public.user_in_module(l.module_id)) then
    raise exception 'card_not_available';
  end if;
  select count(*)::int into recent from public.learn_card_comments x
   where x.user_id = uid and x.created_at > now() - interval '1 minute';
  if recent >= 10 then raise exception 'rate_limited'; end if;
  if p_parent is not null and not exists (
    select 1 from public.learn_card_comments x where x.id = p_parent and x.card_id = p_card
  ) then p_parent := null; end if;
  insert into public.learn_card_comments (card_id, user_id, parent_id, body)
  values (p_card, uid, p_parent, v_body) returning id into cid;
  return cid;
end $$;

create or replace function public.get_card_comments(
  p_card bigint, p_before timestamptz default null, p_limit integer default 30
)
returns table (
  id uuid, user_id uuid, username text, avatar_url text, avatar_blurhash text,
  body text, parent_id uuid, created_at timestamptz, is_mine boolean
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not exists (select 1 from public.learn_cards c join public.learn_lessons l on l.id = c.lesson_id
                  where c.id = p_card and l.status = 'published' and public.user_in_module(l.module_id)) then
    raise exception 'card_not_available';
  end if;
  return query
  select x.id, x.user_id, p.username, p.avatar_url, p.avatar_blurhash,
         x.body, x.parent_id, x.created_at, (x.user_id = auth.uid())
  from public.learn_card_comments x
  join public.profiles p on p.id = x.user_id
  where x.card_id = p_card and x.deleted_at is null
    and (p_before is null or x.created_at < p_before)
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = x.user_id)
         or (b.blocker_id = x.user_id and b.blocked_id = auth.uid()))
  order by x.created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end $$;

create or replace function public.delete_card_comment(p_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.learn_card_comments set deleted_at = now()
   where id = p_id and deleted_at is null and (user_id = auth.uid() or public.is_admin());
  return found;
end $$;


-- =============================================================================
-- PUSH AND REMINDERS
-- =============================================================================
create or replace function public.register_push_token(p_token text, p_platform text default 'android')
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_token is null or char_length(p_token) < 20 then raise exception 'invalid_token'; end if;
  insert into public.push_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), coalesce(nullif(p_platform, ''), 'android'), now())
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end $$;

create or replace function public.unregister_push_token(p_token text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from public.push_tokens where token = p_token and user_id = auth.uid();
end $$;

create or replace function public.set_reminders(p_enabled boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  insert into public.user_reminder_state (user_id, unsubscribed)
  values (auth.uid(), not coalesce(p_enabled, true))
  on conflict (user_id) do update set unsubscribed = not coalesce(p_enabled, true);
end $$;

-- SERVICE ONLY: who should get the next reminder (day 2 -> 4 -> 7 -> 14 -> stop)
create or replace function public.due_reminders()
returns table (user_id uuid, step smallint, days_inactive integer, lang text, university_id integer)
language sql stable security definer set search_path = public as $$
  select s.user_id,
         (s.step + 1)::smallint,
         floor(extract(epoch from (now() - s.last_active_at)) / 86400)::int,
         coalesce(p.preferred_language, 'en'),
         p.university_id
  from public.user_reminder_state s
  join public.profiles p on p.id = s.user_id
  where not s.unsubscribed
    and s.step < 4
    and now() - s.last_active_at >= (case s.step
          when 0 then interval '2 days'
          when 1 then interval '4 days'
          when 2 then interval '7 days'
          else        interval '14 days' end)
    and (s.last_sent_at is null or s.last_sent_at < now() - interval '20 hours')
$$;

create or replace function public.mark_reminder_sent(p_user uuid, p_step smallint)
returns void language sql security definer set search_path = public as $$
  update public.user_reminder_state
     set step = p_step, last_sent_at = now()
   where user_id = p_user and step < p_step
$$;


-- =============================================================================
-- ACCOUNT DELETION (store policy): covers every table that has a user's data
-- cascade (automatic): chat messages, card likes/saves/comments, quiz attempts, daily time,
--   push tokens, reminder state, notifications, learn progress
-- =============================================================================
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
declare target_user uuid := auth.uid();
begin
  if target_user is null then raise exception 'Not authenticated'; end if;

  delete from public.study_resource_upvotes where user_id = target_user;
  delete from public.study_bookmarks         where user_id = target_user;
  delete from public.study_stats             where user_id = target_user;
  update public.study_resources set uploader_id = null where uploader_id = target_user;

  delete from public.blocked_users where blocker_id = target_user or blocked_id = target_user;
  delete from public.reports       where reporter_id = target_user;

  -- Kampus Store: keep the orders for accounting, detach them from the person
  update public.kampus_store_orders set student_id = null where student_id = target_user;
  update public.kampus_store_orders set called_by  = null where called_by  = target_user;

  delete from public.profiles where id = target_user;     -- cascades to the rest
  delete from auth.users      where id = target_user;
end $$;


-- =============================================================================
-- EXECUTE RIGHTS: remove the default public/anon access, grant exactly what is needed
-- =============================================================================
do $$
declare f record;
begin
  -- signed-in users
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'is_admin','my_module_ids','user_in_module',
      'get_onboarding_options','complete_onboarding','set_language','get_me',
      'get_my_modules','get_module_bundle',
      'get_home_cards','review_card','submit_answer','complete_lesson','log_study_time',
      'get_chat_messages','post_chat_message','delete_chat_message',
      'add_module_resource','toggle_resource_upvote','register_download',
      'toggle_card_like','toggle_card_save','add_card_comment','get_card_comments','delete_card_comment',
      'register_push_token','unregister_push_token','set_reminders','delete_my_account')
  loop
    execute format('revoke all on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;

  -- service role only
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('due_reminders','mark_reminder_sent')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;

  -- internal helpers: nobody calls these from outside
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in
      ('_touch_activity','_register_file','_assert_can_contribute','trg_bump_module_version')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;
