-- 49_TEST_B10.sql - run AFTER 48. Changes nothing (ends with an error on purpose).
-- Expected last line: "B10 TEST: ALL 2 PASSED (rolled back on purpose)" (+ "review test skipped" if the user has no card).
do $t$
declare
  v_uid uuid; v_ok int := 0; v_xp0 int; v_xp1 int; v_card bigint; v_note text := '';
  v_cap int := public._cfg_int('xp_daily_cap', 500);
begin
  select p.id into v_uid from public.profiles p where not coalesce(p.is_admin, false) and p.speciality_id is not null limit 1;
  if v_uid is null then raise exception 'B10 TEST: no onboarded profile'; end if;

  -- T1 the daily cap holds even for a huge XP request
  select coalesce(xp, 0) into v_xp0 from public.study_stats where user_id = v_uid;
  perform public._touch_activity(v_uid, 100000);
  perform public._touch_activity(v_uid, 100000);
  select xp into v_xp1 from public.study_stats where user_id = v_uid;
  if v_xp1 - coalesce(v_xp0, 0) > v_cap then raise exception 'B10 TEST T1 FAILED: +% XP (cap %)', v_xp1 - coalesce(v_xp0,0), v_cap; end if;
  v_ok := v_ok + 1;

  -- T2 reviewing the same card twice: the second (card not due) gives 0 XP
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  update public.study_daily set xp = 0 where user_id = v_uid and day = public.algiers_today();
  select c.id into v_card from public.learn_cards c join public.learn_lessons l on l.id = c.lesson_id
   where l.status = 'published' and l.module_id in (select public.my_module_ids()) limit 1;
  if v_card is null then
    v_note := ' (review test skipped: no card)';
  else
    perform public.review_card(v_card, true);
    select xp into v_xp0 from public.study_stats where user_id = v_uid;
    perform public.review_card(v_card, true);
    select xp into v_xp1 from public.study_stats where user_id = v_uid;
    if v_xp1 <> v_xp0 then raise exception 'B10 TEST T2 FAILED: card not due still gave % XP', v_xp1 - v_xp0; end if;
  end if;
  v_ok := v_ok + 1;

  raise exception 'B10 TEST: ALL % PASSED (rolled back on purpose)%', v_ok, v_note;
end $t$;
