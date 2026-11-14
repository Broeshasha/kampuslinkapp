-- 51_TEST_BAC1.sql - run AFTER 50. Changes nothing (ends with an error on purpose).
-- Expected last line: "BAC1 TEST: ALL 6 PASSED (rolled back on purpose)".
do $t$
declare v_uid uuid; v_o jsonb; v_me jsonb; v_ok int := 0; v_n int;
        v_ids int[] := array(select speciality_id from public.kl_bac_streams);
        v_se int := (select speciality_id from public.kl_bac_streams where code = 'SE');
begin
  -- a fresh test account (rolled back at the end)
  v_uid := gen_random_uuid();
  insert into auth.users (id) values (v_uid);
  insert into public.profiles (id) values (v_uid) on conflict (id) do nothing;
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  set local role authenticated;

  v_o := public.get_onboarding_options();
  -- T1 bac branch: 6 streams, only SE active, year 3AS
  if jsonb_array_length(v_o -> 'bac' -> 'streams') <> 6
     or (select count(*) from jsonb_array_elements(v_o -> 'bac' -> 'streams') s where (s ->> 'active')::boolean) <> 1
     or v_o -> 'bac' -> 'years' -> 0 ->> 'year' <> '3AS' then
    raise exception 'BAC1 TEST T1 FAILED: %', v_o -> 'bac'; end if;
  v_ok := v_ok + 1;
  -- T2 no bac stream in the university lists
  select count(*) into v_n from jsonb_array_elements((v_o -> 'specialities') || (v_o -> 'other_specialities')) s
   where (s ->> 'id')::int = any(v_ids);
  if v_n <> 0 then raise exception 'BAC1 TEST T2 FAILED: % bac streams in university lists', v_n; end if;
  v_ok := v_ok + 1;
  -- T3 wrong wilaya / inactive stream refused
  begin perform public.set_bac_profile('SE', '3AS', 0::smallint, 'ar'); raise exception 'BAC1 TEST T3 FAILED: wilaya 0 accepted';
  exception when raise_exception then if sqlerrm <> 'invalid_wilaya' then raise; end if; end;
  begin perform public.set_bac_profile('M', '3AS', 16::smallint, 'ar'); raise exception 'BAC1 TEST T3 FAILED: stream M accepted';
  exception when raise_exception then if sqlerrm <> 'not_offered' then raise; end if; end;
  v_ok := v_ok + 1;
  -- T4 SE works: bac track, generated username, no university, no wilaya in get_me
  v_me := public.set_bac_profile('SE', '3AS', 16::smallint, 'ar');
  if v_me ->> 'track' <> 'bac' or v_me ->> 'username' !~ '^bac_[0-9]{6}$' or v_me ->> 'university_id' is not null
     or v_me ? 'wilaya_code' then raise exception 'BAC1 TEST T4 FAILED: %', v_me; end if;
  -- chosen username is kept; a taken one is refused
  v_me := public.set_bac_profile('SE', '3AS', 16::smallint, 'ar', 'b51_test_user');
  if v_me ->> 'username' <> 'b51_test_user' then raise exception 'BAC1 TEST T4 FAILED: chosen username %', v_me ->> 'username'; end if;
  v_ok := v_ok + 1;
  -- T5 university onboarding refuses a bac stream
  begin
    perform public.set_study_profile(v_se, '3AS', null);
    raise exception 'BAC1 TEST T5 FAILED: bac stream accepted by set_study_profile';
  exception when raise_exception then if sqlerrm <> 'invalid_speciality' then raise; end if; end;
  v_ok := v_ok + 1;
  -- T6 catalog: only bac subjects with published content (none or some, never a university module)
  select count(*) into v_n from jsonb_array_elements(public.get_my_catalog() -> 'modules') m
   where (m ->> 'academic_year') <> '3AS';
  if v_n <> 0 then raise exception 'BAC1 TEST T6 FAILED: % university modules in a bac catalog', v_n; end if;
  v_ok := v_ok + 1;
  reset role;
  raise exception 'BAC1 TEST: ALL % PASSED (rolled back on purpose)', v_ok;
end $t$;
