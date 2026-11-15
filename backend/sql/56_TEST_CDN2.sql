-- 56_TEST_CDN2.sql - run AFTER 55. Changes nothing (ends with an error on purpose).
-- Expected last line: "CDN2 TEST: ALL 7 PASSED (rolled back on purpose)".
do $t$
declare v_uid uuid; v_mod bigint; v_ver int; v_r jsonb; v_r2 jsonb; v_ok int := 0;
        v_path text := 'v1/m/1/1-0123456789abcdef/manifest.json';
begin
  select p.id into v_uid from public.profiles p where not coalesce(p.is_admin, false)
     and p.speciality_id is not null limit 1;
  if v_uid is null then raise exception 'CDN2 TEST: no onboarded profile'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select id into v_mod from public.my_module_ids() as t(id) order by 1 limit 1;
  reset role;
  if v_mod is null then raise exception 'CDN2 TEST: the test student has no module'; end if;
  insert into public.module_content_versions (module_id) values (v_mod) on conflict (module_id) do nothing;
  select version into v_ver from public.module_content_versions where module_id = v_mod;
  update public.module_content_versions set cdn_path = v_path, cdn_version = v_ver where module_id = v_mod;

  -- T1: percent 0 = nobody
  update public.app_config set value = '0'::jsonb where key = 'cdn_percent';
  set local role authenticated;
  v_r := public.app_open(null);
  if (v_r -> 'cdn') is distinct from '{}'::jsonb then raise exception 'CDN2 TEST T1 FAILED: %', v_r -> 'cdn'; end if;
  v_ok := v_ok + 1;
  reset role;

  -- T2: percent 100 = the path of the student's module
  update public.app_config set value = '100'::jsonb where key = 'cdn_percent';
  set local role authenticated;
  v_r := public.app_open(null);
  if (v_r -> 'cdn' ->> v_mod::text) is distinct from v_path then raise exception 'CDN2 TEST T2 FAILED: %', v_r -> 'cdn'; end if;
  v_ok := v_ok + 1;
  -- T3: old keys still there, catalog not re-sent with the same hash
  if jsonb_typeof(v_r -> 'me') <> 'object' or jsonb_typeof(v_r -> 'wallet') <> 'object'
     or jsonb_typeof(v_r -> 'catalog') <> 'object' then raise exception 'CDN2 TEST T3 FAILED: keys'; end if;
  v_r2 := public.app_open(v_r ->> 'catalog_hash');
  if jsonb_typeof(v_r2 -> 'catalog') <> 'null' then raise exception 'CDN2 TEST T3 FAILED: catalog sent again'; end if;
  v_ok := v_ok + 1;
  -- T4: the hash ignores generated_at
  if (v_r ->> 'catalog_hash') is distinct from md5(((v_r -> 'catalog') - 'generated_at')::text) then
    raise exception 'CDN2 TEST T4 FAILED: hash'; end if;
  v_ok := v_ok + 1;
  reset role;

  -- T5: content changed after the publish (version moved) = no path, phones use Supabase
  update public.module_content_versions set version = v_ver + 1 where module_id = v_mod;
  set local role authenticated;
  if public.get_my_cdn_paths() ? v_mod::text then raise exception 'CDN2 TEST T5 FAILED: stale path sent'; end if;
  v_ok := v_ok + 1;

  -- T6: library list
  if jsonb_typeof(public.get_module_resources(v_mod)) <> 'array' then raise exception 'CDN2 TEST T6 FAILED'; end if;
  begin
    perform public.get_module_resources(-1);
    raise exception 'CDN2 TEST T6 FAILED: foreign module allowed';
  exception when others then
    if sqlerrm <> 'not_in_module' then raise; end if;
  end;
  v_ok := v_ok + 1;
  reset role;

  -- T7: anon cannot run
  if has_function_privilege('anon', 'public.get_my_cdn_paths()', 'execute')
     or has_function_privilege('anon', 'public.get_module_resources(bigint)', 'execute')
     or has_function_privilege('anon', 'public.app_open(text)', 'execute') then
    raise exception 'CDN2 TEST T7 FAILED: anon can run'; end if;
  v_ok := v_ok + 1;
  raise exception 'CDN2 TEST: ALL % PASSED (rolled back on purpose)', v_ok;
end $t$;
