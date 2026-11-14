-- 47_TEST_APP_OPEN.sql - run AFTER 46. Changes nothing (ends with an error on purpose).
-- Expected last line: "APP_OPEN TEST: ALL 3 PASSED (rolled back on purpose)".
do $t$
declare v_uid uuid; v_r jsonb; v_r2 jsonb; v_ok int := 0;
begin
  select p.id into v_uid from public.profiles p where not coalesce(p.is_admin, false)
     and p.speciality_id is not null limit 1;
  if v_uid is null then raise exception 'APP_OPEN TEST: no onboarded profile'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v_r := public.app_open(null);
  if jsonb_typeof(v_r -> 'me') <> 'object' or jsonb_typeof(v_r -> 'wallet') <> 'object'
     or jsonb_typeof(v_r -> 'catalog') <> 'object' then
    raise exception 'APP_OPEN TEST T1 FAILED: keys %', (select array_agg(k) from jsonb_object_keys(v_r) k); end if;
  v_ok := v_ok + 1;
  v_r2 := public.app_open(v_r ->> 'catalog_hash');
  if jsonb_typeof(v_r2 -> 'catalog') <> 'null' then raise exception 'APP_OPEN TEST T2 FAILED: catalog sent again'; end if;
  v_ok := v_ok + 1;
  if (v_r2 -> 'me') is distinct from (v_r -> 'me') then raise exception 'APP_OPEN TEST T3 FAILED: me differs'; end if;
  v_ok := v_ok + 1;
  reset role;
  raise exception 'APP_OPEN TEST: ALL % PASSED (rolled back on purpose)', v_ok;
end $t$;
