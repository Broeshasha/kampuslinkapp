-- 45_TEST_B05.sql - run AFTER 44. Changes nothing: it ends with an error on purpose (= rollback).
-- Expected last line: "B05 TEST: ALL 5 PASSED (rolled back on purpose)".
do $t$
declare
  v_uid uuid; v_ok int := 0; v_r jsonb; v_op uuid := gen_random_uuid(); v_n int;
begin
  select id into v_uid from public.profiles where not coalesce(is_admin, false) limit 1;
  if v_uid is null then raise exception 'B05 TEST: no non-admin profile'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- T1 an op is recorded once; T2 sending it again = duplicate
  v_r := public.sync_progress(jsonb_build_array(jsonb_build_object(
           'op_id', v_op, 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 1))));
  if v_r -> 0 ->> 'status' not in ('applied', 'rejected') then
    raise exception 'B05 TEST T1 FAILED: %', v_r; end if;
  v_ok := v_ok + 1;
  v_r := public.sync_progress(jsonb_build_array(jsonb_build_object(
           'op_id', v_op, 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 1))));
  if v_r -> 0 ->> 'status' <> 'duplicate' then raise exception 'B05 TEST T2 FAILED: %', v_r; end if;
  v_ok := v_ok + 1;

  -- T3 bad op id and unknown kind are rejected, not errors
  v_r := public.sync_progress(jsonb_build_array(
           jsonb_build_object('op_id', 'not-a-uuid', 'kind', 'review'),
           jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'b05_unknown')));
  if v_r -> 0 ->> 'message' <> 'invalid_op_id' or v_r -> 1 ->> 'status' <> 'rejected' then
    raise exception 'B05 TEST T3 FAILED: %', v_r; end if;
  v_ok := v_ok + 1;
  reset role;

  -- T4 no policy left that runs auth.uid() / user_in_module() per row (store excluded)
  select count(*) into v_n from pg_policies where schemaname = 'public' and tablename !~ '^(kampus_store|ks_)'
     and ((coalesce(qual,'') || ' ' || coalesce(with_check,'')) ~ '(?<!SELECT )auth\.uid\(\)'
          or (coalesce(qual,'') || coalesce(with_check,'')) ~ 'user_in_module\(');
  if v_n <> 0 then raise exception 'B05 TEST T4 FAILED: % policies still per row', v_n; end if;
  v_ok := v_ok + 1;

  -- T5 nightly purge scheduled
  if not exists (select 1 from cron.job where jobname = 'purge-client-ops') then
    raise exception 'B05 TEST T5 FAILED: no purge job'; end if;
  v_ok := v_ok + 1;

  raise exception 'B05 TEST: ALL % PASSED (rolled back on purpose)', v_ok;
end
$t$;
