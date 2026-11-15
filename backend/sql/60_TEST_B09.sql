-- 60_TEST_B09.sql - run AFTER 59. Changes nothing (ends with an error on purpose).
-- Expected last line: "B09 TEST: ALL 6 PASSED (rolled back on purpose)".
do $t$
declare v_uid uuid; v_old bigint; v_card bigint; v_card2 bigint; v_q bigint; v_lesson bigint; v_ok int := 0; r jsonb;
        today date := public.algiers_today(); st public.study_stats;
        sat timestamptz; sun timestamptz;
begin
  -- a student + a published card, question and lesson of his modules
  for v_uid in select p.id from public.profiles p limit 300 loop
    perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    select c.id, l.id into v_card, v_lesson from public.learn_cards c join public.learn_lessons l on l.id = c.lesson_id
     where l.status = 'published' and l.module_id in (select public.my_module_ids()) limit 1;
    exit when v_card is not null;
  end loop;
  if v_card is null then raise exception 'B09 TEST: no student with a card'; end if;
  select c.id into v_card2 from public.learn_cards c where c.lesson_id = v_lesson and c.id <> v_card limit 1;
  select q.id into v_q from public.learn_questions q join public.learn_lessons l on l.id = q.lesson_id
   where l.status = 'published' and l.module_id in (select public.my_module_ids()) limit 1;

  -- clean slate for this student inside the test transaction
  delete from public.study_daily where user_id = v_uid and day >= today - 3;
  delete from public.learn_card_progress where user_id = v_uid and card_id in (v_card, v_card2);
  insert into public.study_stats (user_id) values (v_uid) on conflict (user_id) do nothing;
  update public.study_stats set current_streak = 0, last_active_date = today - 10 where user_id = v_uid;
  sat := ((today - 2)::timestamp + time '18:00') at time zone 'Africa/Algiers';
  sun := ((today - 1)::timestamp + time '18:00') at time zone 'Africa/Algiers';

  set local role authenticated;
  -- T1: offline Saturday + Sunday, synced today -> 3-day streak, reviews on the right days
  r := public.sync_progress(jsonb_build_array(
    jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'review', 'payload', jsonb_build_object('card_id', v_card, 'correct', true, 'at', sat)),
    jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'review', 'payload', jsonb_build_object('card_id', v_card2, 'correct', true, 'at', sun)),
    jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 400, 'at', sun)),
    jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'review', 'payload', jsonb_build_object('card_id', v_card, 'correct', true))));
  reset role;
  if exists (select 1 from jsonb_array_elements(r) e where e ->> 'status' <> 'applied') then
    raise exception 'B09 TEST T1 FAILED: %', r; end if;
  select * into st from public.study_stats where user_id = v_uid;
  if st.current_streak <> 3 or st.last_active_date <> today then
    raise exception 'B09 TEST T1 FAILED: streak % last %', st.current_streak, st.last_active_date; end if;
  v_ok := v_ok + 1;
  -- T2: study time + review counted on Sunday, not today
  if (select active_seconds from public.study_daily where user_id = v_uid and day = today - 1) is distinct from 400
     or (select cards_reviewed from public.study_daily where user_id = v_uid and day = today - 2) is distinct from 1 then
    raise exception 'B09 TEST T2 FAILED: days wrong'; end if;
  v_ok := v_ok + 1;
  -- T3: due date counted from the real review time
  if (select last_reviewed_at from public.learn_card_progress where user_id = v_uid and card_id = v_card2) <> sun then
    raise exception 'B09 TEST T3 FAILED: review time'; end if;
  v_ok := v_ok + 1;

  -- T4: a late op from before the last active day never breaks the streak
  set local role authenticated;
  r := public.sync_progress(jsonb_build_array(
    jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'review',
                       'payload', jsonb_build_object('card_id', v_card2, 'correct', false, 'at', sat))));
  reset role;
  if (select current_streak from public.study_stats where user_id = v_uid) <> 3 then
    raise exception 'B09 TEST T4 FAILED: streak changed'; end if;
  v_ok := v_ok + 1;

  -- T5: future, 30-days-old and garbage dates are clamped (no rejection). Only rows THIS test touches are
  -- compared (the student may have real study days older than 14 days).
  select coalesce(sum(active_seconds), 0) into v_old from public.study_daily where user_id = v_uid and day < today - 14;
  set local role authenticated;
  r := public.sync_progress(jsonb_build_array(
    jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 10, 'at', now() + interval '3 days')),
    jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 10, 'at', now() - interval '30 days')),
    jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 10, 'at', 'yesterday!'))));
  reset role;
  if exists (select 1 from jsonb_array_elements(r) e where e ->> 'status' <> 'applied')
     or exists (select 1 from public.study_daily where user_id = v_uid and day > today)
     or (select coalesce(sum(active_seconds), 0) from public.study_daily where user_id = v_uid and day < today - 14) <> v_old then
    raise exception 'B09 TEST T5 FAILED: %', r; end if;
  v_ok := v_ok + 1;

  -- T6: old 2-argument calls still work; anon cannot run
  set local role authenticated;
  perform public.review_card(v_card, true);
  perform public.log_study_time(5);
  if v_q is not null then perform public.submit_answer(v_q, 0); end if;
  perform public.complete_lesson(v_lesson, 50);
  reset role;
  if has_function_privilege('anon', 'public.review_card(bigint,boolean,timestamptz)', 'execute') then
    raise exception 'B09 TEST T6 FAILED: anon'; end if;
  v_ok := v_ok + 1;
  raise exception 'B09 TEST: ALL % PASSED (rolled back on purpose)', v_ok;
end $t$;
