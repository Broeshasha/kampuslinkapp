-- =============================================================================
-- KAMPUSLINK BACKEND  |  05  CHECKS AND TESTS (run after 04)
-- =============================================================================
-- Run ONE block at a time. Every block only reads, or tests inside a transaction that is
-- rolled back on purpose (the DO blocks end with an exception that carries the result).
-- Send me the result of each block.
-- =============================================================================


-- =============================================================================
-- C1  Does everything v1 expects exist? (both lists must come back EMPTY)
-- =============================================================================
with expected_tables(t) as (values
  ('app_config'),('push_tokens'),
  ('user_reminder_state'),('study_daily'),('module_chat_messages'),('message_translations'),
  ('module_glossary'),('learn_card_likes'),('learn_card_saves'),('learn_card_comments'),
  ('learn_quiz_attempts'),('learn_lesson_resources'),('module_content_versions'),
  ('public_profiles'),('profiles'),('study_modules'),('study_resources'),('learn_lessons'),
  ('learn_cards'),('learn_questions'),('learn_card_progress'),('learn_lesson_progress'))
select 'missing table/view' as problem, t as name
from expected_tables where to_regclass('public.' || t) is null
union all
select 'missing function', f
from unnest(array[
  'algiers_today','is_admin','my_module_ids','user_in_module',
  'get_onboarding_options','complete_onboarding','set_language','get_me',
  'get_my_modules','get_module_bundle','get_home_cards','review_card','submit_answer',
  'complete_lesson','log_study_time','get_chat_messages','post_chat_message',
  'delete_chat_message','add_module_resource','toggle_resource_upvote','register_download',
  'toggle_card_like','toggle_card_save','add_card_comment','get_card_comments',
  'delete_card_comment','register_push_token','unregister_push_token',
  'set_reminders','delete_my_account',
  'due_reminders','mark_reminder_sent','_touch_activity','_register_file',
  '_assert_can_contribute','trg_bump_module_version']) as f
where not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = f);


-- =============================================================================
-- C2  Row security: tables WITHOUT it (expect: nothing)
-- =============================================================================
select c.relname as table_without_rls
from pg_class c
where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p') and not c.relrowsecurity
order by 1;


-- =============================================================================
-- C3  Who can call what: functions that anon can execute (expect ONLY old Store/legacy ones:
--     apply_sync, set_costs, set_product_slug, ks_is_dead, ks_is_delivered, ks_snapshot_prices,
--     ks_stamp_delivered, protect_is_admin, handle_new_user, call_send_push should be GONE,
--     get_my_profile() etc. is authenticated-only)
-- =============================================================================
select p.proname, pg_get_function_identity_arguments(p.oid) as args, p.prosecdef as security_definer
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.prokind = 'f'
  and has_function_privilege('anon', p.oid, 'execute')
order by p.proname;


-- =============================================================================
-- C4  Policies per table (look for any table with 0 policies that clients should read)
-- =============================================================================
select c.relname as table_name,
       count(pol.polname) as policies,
       string_agg(pol.polname || ' (' ||
         case pol.polcmd when 'r' then 'select' when 'a' then 'insert' when 'w' then 'update'
                         when 'd' then 'delete' else 'all' end || ')', ', ' order by pol.polname) as list
from pg_class c
left join pg_policy pol on pol.polrelid = c.oid
where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
group by c.relname
order by c.relname;


-- =============================================================================
-- C5  How are the ids of the learning tables generated? (decides the sample-content script)
--     attidentity: a = always, d = by default, empty = plain number you must supply
-- =============================================================================
select c.relname as table_name, a.attname, a.attidentity
from pg_attribute a
join pg_class c on c.oid = a.attrelid
where c.relnamespace = 'public'::regnamespace
  and c.relname in ('learn_lessons','learn_cards','learn_questions')
  and a.attname = 'id' and not a.attisdropped;


-- =============================================================================
-- C6  FIND A TEST USER (copy one id for the tests below)
-- =============================================================================
select id, username, university_id, speciality_id, academic_year, onboarding_complete
from public.profiles
order by created_at
limit 20;


-- =============================================================================
-- T1  Read tests as that user (replace the id; nothing is changed)
--     Expect: a JSON profile, then the module list (Mining L2 modules if the profile is
--     Mining year L2), then an empty card list (no content yet).
-- =============================================================================
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', '<TEST-USER-UUID>', 'role', 'authenticated', 'email', 'test@example.com')::text, true);
set local role authenticated;
select public.get_me() as me;
rollback;

-- run these two the same way, one at a time (same begin / set_config / set local role / rollback):
--   select * from public.get_my_modules();
--   select * from public.get_home_cards(5);


-- =============================================================================
-- T2  Write test: study time + streak. The block ENDS WITH AN ERROR ON PURPOSE: that
--     rolls everything back and shows the result in the message. "TEST OK" = good.
-- =============================================================================
do $$
declare r jsonb; m jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '<TEST-USER-UUID>', 'role', 'authenticated', 'email', 'test@example.com')::text, true);
  set local role authenticated;
  r := public.log_study_time(400);
  m := public.get_me();
  raise exception 'TEST OK (rolled back) -> log_study_time: %  | streak: %  | today_seconds: %',
    r, m ->> 'current_streak', m ->> 'today_seconds';
end $$;


-- =============================================================================
-- T3  Write test: onboarding (rolled back). Replace the three numbers with a real
--     university id, the Mining speciality id (2) and year L2.
-- =============================================================================
do $$
declare r jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '<TEST-USER-UUID>', 'role', 'authenticated', 'email', 'test@example.com')::text, true);
  set local role authenticated;
  r := public.complete_onboarding('test_user_01', <UNIVERSITY-ID>, 2, 'L2', 'fr', 'A', 'G1');
  raise exception 'TEST OK (rolled back) -> %', r;
end $$;


-- =============================================================================
-- T4  Security tests (each must FAIL or return nothing; run as an ordinary user)
-- =============================================================================
-- a) a signed-in user must NOT be able to read another person's full profile row:
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', '<TEST-USER-UUID>', 'role', 'authenticated')::text, true);
set local role authenticated;
select count(*) as other_profiles_visible_through_table
from public.profiles where id <> '<TEST-USER-UUID>';       -- expect 0
rollback;

-- b) anon must not read notifications or the library:
begin;
set local role anon;
select (select count(*) from public.notifications) as notifications_visible,   -- expect 0 (or permission denied)
       (select count(*) from public.study_resources) as resources_visible;       -- expect permission denied
rollback;
