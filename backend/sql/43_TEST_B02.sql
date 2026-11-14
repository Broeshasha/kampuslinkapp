-- 43_TEST_B02.sql - run AFTER 42. Changes nothing: it ends with an error on purpose (= rollback).
-- Expected last line: "B02 TEST: ALL 7 PASSED (rolled back on purpose)".
do $t$
declare
  v_uid uuid; v_ok int := 0; v_n int; v_n0 int; v_goal int; v_tbl text; v_row jsonb; v_cols text;
begin
  select id into v_uid from public.profiles where not coalesce(is_admin, false) limit 1;
  if v_uid is null then raise exception 'B02 TEST: no non-admin profile found'; end if;
  -- report template: copy a real report (any other reporter) so every NOT NULL column has a valid value
  select to_jsonb(r) into v_row from public.reports r where r.reporter_id <> v_uid limit 1;
  if v_row is null then
    v_row := jsonb_build_object('target_type', 'message', 'target_id', gen_random_uuid()::text, 'reason', 'spam');
    -- no reports yet: take allowed values from the table's CHECK constraints (first value in each list)
    foreach v_tbl in array array['target_type','reason'] loop
      select substring(pg_get_constraintdef(c.oid) from '''([^'']+)''') into v_cols
        from pg_constraint c where c.conrelid = 'public.reports'::regclass and c.contype = 'c'
         and pg_get_constraintdef(c.oid) ~ ('\m' || v_tbl || '\M') and pg_get_constraintdef(c.oid) like '%''%' limit 1;
      if v_cols is not null then v_row := v_row || jsonb_build_object(v_tbl, v_cols); end if;
      v_cols := null;
    end loop;
  end if;
  v_row := (v_row - 'id' - 'created_at') || jsonb_build_object('reporter_id', v_uid, 'details', 'b02 test');
  select string_agg(quote_ident(k), ', ') into v_cols from jsonb_object_keys(v_row) k;
  select count(*) into v_n0 from public.reports where reporter_id = v_uid;
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

  -- T6 same report twice = one new row (counted as postgres, reports are not readable by users)
  execute format('insert into public.reports (%s) select %s from jsonb_populate_record(null::public.reports, $1)', v_cols, v_cols) using v_row;
  execute format('insert into public.reports (%s) select %s from jsonb_populate_record(null::public.reports, $1)', v_cols, v_cols) using v_row;
  reset role;
  select count(*) - v_n0 into v_n from public.reports where reporter_id = v_uid;
  if v_n <> 1 then raise exception 'B02 TEST T6 FAILED: % new rows for one target', v_n; end if;
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
