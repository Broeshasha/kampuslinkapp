-- =====================================================================
-- 44_B05_LIGHT_SYNC.sql  (B05 - C-04 server, B-17, C-16, C-17, C-20)
-- Run ONCE in the Supabase SQL editor (whole file). Safe to re-run.
-- Old sync_progress body: 44_ROLLBACK_SYNC_PROGRESS.sql (run it to undo step 1).
-- statement_timeout: already 8 s (authenticated) / 3 s (anon) on production -> nothing to do (C-11).
-- too_many_ops stays 200 until build 10 (batch 25) is min_supported_build, then 50 (separate file).
-- Kampus Store tables/policies: not touched.
-- =====================================================================

-- 1) sync_progress: fewer sub-transactions, module list read once, server trouble aborts the call.
create or replace function public.sync_progress(p_ops jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  uid     uuid := auth.uid();
  item    jsonb;
  v_raw   text;
  v_id    uuid;
  v_kind  text;
  v_pl    jsonb;
  v_card  bigint;
  v_st    text;
  v_msg   text;
  v_coins integer := 0;
  v_mods  bigint[];
  v_streak boolean := false;
  results jsonb := '[]'::jsonb;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_ops is null or jsonb_typeof(p_ops) <> 'array' then raise exception 'invalid_ops'; end if;
  if jsonb_array_length(p_ops) > 200 then raise exception 'too_many_ops'; end if;

  for item in select e.value from jsonb_array_elements(p_ops) e loop
    -- B05: checked by pattern, not by a begin/exception block (one sub-transaction less per op).
    v_raw := item ->> 'op_id';
    if v_raw is null or v_raw !~* '^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$' then
      results := results || jsonb_build_object('op_id', v_raw, 'status', 'rejected', 'message', 'invalid_op_id');
      continue;
    end if;
    v_id    := v_raw::uuid;
    v_kind  := item ->> 'kind';
    v_coins := 0;
    v_pl    := coalesce(item -> 'payload', '{}'::jsonb);

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
      elsif v_kind = 'case_progress' then
        perform public._apply_case_progress(uid, v_pl);
      elsif v_kind = 'content_report' then
        perform public._apply_content_report(uid, v_pl);
      elsif v_kind = 'exam_attempt' then
        perform public._apply_exam_attempt(uid, v_pl);
      elsif v_kind = 'practice_progress' then
        perform public._apply_practice_progress(uid, v_pl);
      elsif v_kind = 'reminder_response' then
        perform public._apply_reminder_response(uid, v_pl);
      elsif v_kind = 'app_open' then
        perform public._apply_app_open(uid, v_pl);
      elsif v_kind = 'story_answer' then
        v_coins := public._apply_story_answer(uid, v_id, v_pl);
      elsif v_kind = 'story_view' then
        perform public._apply_story_view(uid, v_pl);
      elsif v_kind = 'helper_use' then
        perform public._apply_helper_use(uid, v_pl);
      elsif v_kind in ('like', 'save') then
        v_card := (v_pl ->> 'card_id')::bigint;
        if v_mods is null then v_mods := array(select public.my_module_ids()); end if;
        if not exists (select 1 from public.learn_cards c
                         join public.learn_lessons l on l.id = c.lesson_id
                        where c.id = v_card and l.status = 'published' and l.module_id = any(v_mods)) then
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
      -- B05: exam achievements per exam op; the streak achievement once per call (after the loop).
      if v_kind = 'exam_attempt' then
        v_coins := v_coins + public._coins_after_op(uid, v_id, v_kind, v_pl);
      elsif v_kind not in ('app_open', 'reading_position', 'story_view') then
        v_streak := true;
      end if;
      v_st := 'applied'; v_msg := null;
    exception when others then
      -- B-17: server trouble aborts the whole call; the phone keeps the ops and retries later.
      if sqlstate in ('40001', '40P01', '55P03', '57014') then raise; end if;
      v_st := 'rejected'; v_msg := sqlerrm;
    end;

    insert into public.client_ops (user_id, op_id, kind, status, message)
    values (uid, v_id, left(coalesce(v_kind, '?'), 30), v_st, left(v_msg, 200));
    results := results || jsonb_build_object('op_id', v_id, 'status', v_st, 'message', v_msg,
                                             'coins', case when v_st = 'applied' then v_coins else 0 end);
  end loop;

  if v_streak then
    perform public._coins_after_op(uid, null, 'review', '{}'::jsonb);
  end if;
  return results;
end $function$;

revoke all on function public.sync_progress(jsonb) from public, anon;
grant execute on function public.sync_progress(jsonb) to authenticated, service_role;

create temp table if not exists b05_log(n serial, step text, obj text, action text);
truncate b05_log;

do $b05$
declare r record; v_using text; v_check text; v_sql text;
begin
  -- 2) C-17: auth.uid() and user_in_module() evaluated once per query, not once per row.
  for r in select tablename, policyname, qual, with_check from pg_policies
           where schemaname = 'public' and tablename !~ '^(kampus_store|ks_)'
             and (coalesce(qual,'') || coalesce(with_check,'')) ~ '(auth\.uid\(\)|user_in_module\()' loop
    v_using := regexp_replace(regexp_replace(r.qual, '(?<!SELECT )auth\.uid\(\)', '(select auth.uid())', 'g'),
                              'user_in_module\(([a-z_.]+)\)', '(\1 in (select public.my_module_ids()))', 'g');
    v_check := regexp_replace(regexp_replace(r.with_check, '(?<!SELECT )auth\.uid\(\)', '(select auth.uid())', 'g'),
                              'user_in_module\(([a-z_.]+)\)', '(\1 in (select public.my_module_ids()))', 'g');
    if v_using is not distinct from r.qual and v_check is not distinct from r.with_check then continue; end if;
    v_sql := format('alter policy %I on public.%I', r.policyname, r.tablename)
          || case when v_using is not null then ' using (' || v_using || ')' else '' end
          || case when v_check is not null then ' with check (' || v_check || ')' else '' end;
    execute v_sql;
    insert into b05_log(step,obj,action) values ('2 policies', r.tablename || '.' || r.policyname, 'rewritten');
  end loop;

  -- 3) C-16: indexes for lookups by user / resource / status (tables are small: plain create is quick).
  if to_regclass('public.learn_card_likes') is not null then
    create index if not exists learn_card_likes_user_idx on public.learn_card_likes (user_id); end if;
  if to_regclass('public.learn_card_saves') is not null then
    create index if not exists learn_card_saves_user_idx on public.learn_card_saves (user_id); end if;
  if to_regclass('public.study_resource_upvotes') is not null then
    create index if not exists study_resource_upvotes_resource_idx on public.study_resource_upvotes (resource_id); end if;
  if to_regclass('public.learn_card_comments') is not null then
    create index if not exists learn_card_comments_user_idx on public.learn_card_comments (user_id, created_at desc); end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='kl_invites' and column_name='inviter_id') then
    create index if not exists kl_invites_inviter_idx on public.kl_invites (inviter_id); end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='content_reports' and column_name='status') then
    create index if not exists content_reports_open_idx on public.content_reports (status) where status = 'open'; end if;
  insert into b05_log(step,obj,action) values ('3 indexes', 'likes, saves, upvotes, comments, invites, reports', 'created if missing');

  -- 4) C-20: client_ops older than 30 days deleted every night (03:17 UTC).
  perform cron.unschedule(jobid) from cron.job where jobname = 'purge-client-ops';
  perform cron.schedule('purge-client-ops', '17 3 * * *',
    $c$delete from public.client_ops where created_at < now() - interval '30 days'$c$);
  insert into b05_log(step,obj,action) values ('4 cron', 'purge-client-ops', 'daily 03:17 UTC, keeps 30 days');
end
$b05$;

select step, obj, action from b05_log
union all
select 'CHECK policies still per-row', tablename || '.' || policyname, 'PROBLEM'
  from pg_policies where schemaname = 'public' and tablename !~ '^(kampus_store|ks_)'
   and ((coalesce(qual,'') || ' ' || coalesce(with_check,'')) ~ '(?<!SELECT )auth\.uid\(\)'
        or (coalesce(qual,'') || coalesce(with_check,'')) ~ 'user_in_module\(')
union all
select 'CHECK cron', jobname, schedule from cron.job;
