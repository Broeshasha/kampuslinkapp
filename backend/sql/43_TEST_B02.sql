-- 43_TEST_B02.sql - run AFTER 42. Changes nothing: it ends with an error on purpose (= rollback).
-- Expected last line: "B02 TEST: ALL 7 PASSED (rolled back on purpose)".
do $t$
declare
  v_uid uuid; v_ok int := 0; v_n int; v_goal int; v_tbl text;
begin
  select id into v_uid from public.profiles where not coalesce(is_admin, false) limit 1;
  if v_uid is null then raise exception 'B02 TEST: no non-admin profile found'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- T1 username cannot be changed directly
  begin
    update public.profiles set username = 'hacked_b02' where id = v_uid;
    raise exception 'B02 TEST T1 FAILED: username update allowed';
  exception when insufficient_privilege then v_ok := v_ok + 1; end;

  -- T2 study goal still works
  select study_goal_minutes into v_goal from public.profiles where id = v_uid;
  update public.profiles set study_goal_minutes = 30 where id = v_uid;
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'B02 TEST T2 FAILED: study goal update hit % rows', v_n; end if;
  v_ok := v_ok + 1;

  -- T3 out-of-range goal refused
  begin
    update public.profiles set study_goal_minutes = 5000 where id = v_uid;
    raise exception 'B02 TEST T3 FAILED: goal 5000 accepted';
  exception when check_violation then v_ok := v_ok + 1; end;

  -- T4 helper not callable
  begin
    perform public._touch_activity(v_uid, 1000);
    raise exception 'B02 TEST T4 FAILED: _touch_activity callable';
  exception when insufficient_privilege or undefined_function then v_ok := v_ok + 1; end;

  -- T5 no direct content reads for a normal user
  v_n := 0;
  foreach v_tbl in array array['learn_lessons','learn_lesson_i18n','learn_cards','learn_card_i18n',
                               'learn_questions','learn_question_i18n'] loop
    if to_regclass('public.' || v_tbl) is not null then
      execute format('select count(*) from (select 1 from public.%I limit 5) s', v_tbl) into v_goal;
      v_n := v_n + v_goal;
    end if;
  end loop;
  if v_n <> 0 then raise exception 'B02 TEST T5 FAILED: normal user still reads % content rows', v_n; end if;
  v_ok := v_ok + 1;

  -- T6 same report twice = one row (counted as postgres, reports are not readable by users)
  insert into public.reports (reporter_id, target_type, target_id, details) values (v_uid, 'b02_test', 'x1', 'test');
  insert into public.reports (reporter_id, target_type, target_id, details) values (v_uid, 'b02_test', 'x1', 'test');
  reset role;
  select count(*) into v_n from public.reports where reporter_id = v_uid and target_type = 'b02_test';
  if v_n <> 1 then raise exception 'B02 TEST T6 FAILED: % rows for one target', v_n; end if;
  v_ok := v_ok + 1;

  -- T7 anon cannot write profiles
  set local role anon;
  begin
    update public.profiles set username = 'x' where id = v_uid;
    raise exception 'B02 TEST T7 FAILED: anon update allowed';
  exception when insufficient_privilege then v_ok := v_ok + 1; end;
  reset role;

  raise exception 'B02 TEST: ALL % PASSED (rolled back on purpose)', v_ok;
end
$t$;
