-- KAMPUSLINK FILE 34: test of file 33 (coins, shop, stories). Safe: everything is rolled back at the end.
-- Run it in the Supabase SQL editor AFTER file 33. The result appears as an "error" message that starts with TEST RESULT.
-- Read the first words: "SUMMARY: ALL n PASSED" = good. Otherwise every line that starts with FAIL tells what broke.
do $t34$
declare
  uid uuid := '322af894-2767-4a2c-8b1f-03a83b0590d0';
  res text[] := '{}'; fails int := 0; n int := 0;
  r jsonb; w jsonb; s jsonb; item jsonb; op uuid;
  qkey text; qid bigint; ci int; ed1 uuid; ed2 uuid; ed3 uuid; lid bigint; cid bigint;
  bal0 int; bal1 int; c int; i int; msg text; today date := public.algiers_today(); earned int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', uid::text, true);
  update public.profiles set username = 'test_user_a1', is_admin = false, speciality_id = 2, academic_year = 'L2', study_goal_minutes = 5 where id = uid;
  delete from public.kl_coin_ledger where user_id = uid;   -- rolled back with everything else

  -- 1 wallet baseline
  w := public.get_wallet();
  n := n + 1; if (w ->> 'balance')::int = 0 and (w ->> 'daily_cap')::int = 100 then res := array_append(res, 'ok 1 wallet starts at 0, cap 100');
  else fails := fails + 1; res := array_append(res, 'FAIL 1 wallet ' || w::text); end if;

  -- 2 stories: question of the day + templates
  s := public.get_my_stories();
  n := n + 1; if (select count(*) from jsonb_object_keys(s -> 'templates')) = 8 then res := array_append(res, 'ok 2a eight story templates');
  else fails := fails + 1; res := array_append(res, 'FAIL 2a templates'); end if;
  select e ->> 'key', (e -> 'payload' ->> 'question_id')::bigint, (e -> 'payload' ->> 'correct_index')::int into qkey, qid, ci
    from jsonb_array_elements(s -> 'stories') e where e ->> 'template' = 'question' limit 1;
  n := n + 1; if qkey is not null then res := array_append(res, 'ok 2b question of the day found ' || qkey);
  else fails := fails + 1; res := array_append(res, 'FAIL 2b no question of the day (does this student have a module with published questions?)'); end if;
  n := n + 1; if (select count(*) from jsonb_array_elements(public.get_my_stories() -> 'stories') e where e ->> 'template' = 'question' and (e -> 'payload' ->> 'question_id')::bigint = qid) = 1
  then res := array_append(res, 'ok 3 same question when asked again'); else fails := fails + 1; res := array_append(res, 'FAIL 3 question changed'); end if;

  -- 4/5/6 correct answer pays once, resend of the same op = duplicate, new op for the same story = 0
  op := gen_random_uuid();
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', op, 'kind', 'story_answer', 'payload', jsonb_build_object('story_key', qkey, 'choice', ci))));
  n := n + 1; if r -> 0 ->> 'status' = 'applied' and (r -> 0 ->> 'coins')::int = 10 then res := array_append(res, 'ok 4 right answer = +10 coins');
  else fails := fails + 1; res := array_append(res, 'FAIL 4 ' || r::text); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', op, 'kind', 'story_answer', 'payload', jsonb_build_object('story_key', qkey, 'choice', ci))));
  n := n + 1; if r -> 0 ->> 'status' = 'duplicate' then res := array_append(res, 'ok 5 same op twice = duplicate'); else fails := fails + 1; res := array_append(res, 'FAIL 5 ' || r::text); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'story_answer', 'payload', jsonb_build_object('story_key', qkey, 'choice', ci))));
  n := n + 1; if (r -> 0 ->> 'coins')::int = 0 and (public.get_wallet() ->> 'balance')::int = 10 then res := array_append(res, 'ok 6 answering the same story again pays nothing, balance 10');
  else fails := fails + 1; res := array_append(res, 'FAIL 6 ' || r::text); end if;

  -- 7 editorial question stories: wrong = 0 coins, right = +10
  insert into public.kl_stories (template, payload) values ('question', '{"correct_index":1,"i18n":{"en":{"prompt":"t","options":["a","b"],"explanation":"x"}}}') returning id into ed1;
  insert into public.kl_stories (template, payload) values ('question', '{"correct_index":0}') returning id into ed2;
  insert into public.kl_stories (template, payload) values ('question', '{"correct_index":0}') returning id into ed3;
  insert into public.kl_stories (template, payload, publish_at) values ('fun', '{}', now() - interval '30 hours');   -- too old: must not be listed
  n := n + 1; if (select count(*) from jsonb_array_elements(public.get_my_stories() -> 'stories') e where e ->> 'source' = 'editorial') = 3
  then res := array_append(res, 'ok 7a three live editorial stories (the 30h old one is hidden)'); else fails := fails + 1; res := array_append(res, 'FAIL 7a editorial count'); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'story_answer', 'payload', jsonb_build_object('story_key', 'ed:' || ed1, 'choice', 0))));
  n := n + 1; if r -> 0 ->> 'status' = 'applied' and (r -> 0 ->> 'coins')::int = 0 then res := array_append(res, 'ok 7b wrong editorial answer = 0 coins'); else fails := fails + 1; res := array_append(res, 'FAIL 7b ' || r::text); end if;
  n := n + 1; if exists (select 1 from jsonb_array_elements(public.get_my_stories() -> 'stories') e where e ->> 'key' = 'ed:' || ed1 and (e -> 'answered' ->> 'is_correct')::boolean = false)
  then res := array_append(res, 'ok 7c the story now shows answered/wrong'); else fails := fails + 1; res := array_append(res, 'FAIL 7c answered state'); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'story_answer', 'payload', jsonb_build_object('story_key', 'ed:' || ed2, 'choice', 0))));
  n := n + 1; if (r -> 0 ->> 'coins')::int = 10 then res := array_append(res, 'ok 7d right editorial answer = +10'); else fails := fails + 1; res := array_append(res, 'FAIL 7d ' || r::text); end if;

  -- 8 episode done pays once per lesson; a card at the top Leitner box pays once per card
  select l.id into lid from public.learn_lessons l where l.status = 'published' and l.module_id in (select t.id from public.my_module_ids() as t(id)) order by l.id limit 1;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'lesson_done', 'payload', jsonb_build_object('lesson_id', lid, 'score', 80))));
  n := n + 1; if (r -> 0 ->> 'coins')::int = 10 then res := array_append(res, 'ok 8a lesson done = +10'); else fails := fails + 1; res := array_append(res, 'FAIL 8a ' || r::text); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'lesson_done', 'payload', jsonb_build_object('lesson_id', lid, 'score', 90))));
  n := n + 1; if (r -> 0 ->> 'coins')::int = 0 then res := array_append(res, 'ok 8b same lesson again = 0'); else fails := fails + 1; res := array_append(res, 'FAIL 8b ' || r::text); end if;
  select c2.id into cid from public.learn_cards c2 join public.learn_lessons l on l.id = c2.lesson_id
   where l.status = 'published' and l.module_id in (select t.id from public.my_module_ids() as t(id)) order by c2.id limit 1;
  c := 0;
  for i in 1..5 loop
    r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'review', 'payload', jsonb_build_object('card_id', cid, 'correct', true))));
    c := c + coalesce((r -> 0 ->> 'coins')::int, 0);
  end loop;
  n := n + 1; if c = 3 then res := array_append(res, 'ok 8c card reaches box 5 = +3, only once'); else fails := fails + 1; res := array_append(res, 'FAIL 8c coins=' || c); end if;

  -- 9 daily goal (test goal = 5 minutes)
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 300))));
  n := n + 1; if (r -> 0 ->> 'coins')::int = 15 then res := array_append(res, 'ok 9a daily goal reached = +15'); else fails := fails + 1; res := array_append(res, 'FAIL 9a ' || r::text); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 300))));
  n := n + 1; if (r -> 0 ->> 'coins')::int = 0 then res := array_append(res, 'ok 9b daily goal pays once a day'); else fails := fails + 1; res := array_append(res, 'FAIL 9b ' || r::text); end if;

  -- 10 daily cap: leave only 5 coins of room, a +10 reward is cut to +5, then nothing
  earned := (public.get_wallet() ->> 'today_earned')::int;
  update public.app_config set value = to_jsonb(earned + 5) where key = 'coins_daily_cap';
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'story_answer', 'payload', jsonb_build_object('story_key', 'ed:' || ed3, 'choice', 0))));
  n := n + 1; if (r -> 0 ->> 'coins')::int = 5 and (public.get_wallet() ->> 'cap_remaining')::int = 0 then res := array_append(res, 'ok 10 daily cap cuts +10 to +5, nothing left');
  else fails := fails + 1; res := array_append(res, 'FAIL 10 ' || r::text); end if;
  update public.app_config set value = '100'::jsonb where key = 'coins_daily_cap';

  -- 11 streak milestone (not under the daily cap): yesterday streak 2 -> today 3 -> +20, once
  update public.study_stats set current_streak = 2, last_active_date = today - 1 where user_id = uid;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 60))));
  n := n + 1; if (r -> 0 ->> 'coins')::int = 20 and (public.get_wallet() -> 'streak' ->> 'current')::int = 3 then res := array_append(res, 'ok 11a streak 3 = +20');
  else fails := fails + 1; res := array_append(res, 'FAIL 11a ' || r::text); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 60))));
  n := n + 1; if (r -> 0 ->> 'coins')::int = 0 then res := array_append(res, 'ok 11b milestone pays once'); else fails := fails + 1; res := array_append(res, 'FAIL 11b ' || r::text); end if;

  -- 12 shop
  bal0 := (public.get_wallet() ->> 'balance')::int;
  begin perform public.buy_item('streak_freeze'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 12a bought with ' || bal0 || ' coins');
  exception when others then n := n + 1; if sqlerrm = 'insufficient_coins' then res := array_append(res, 'ok 12a not enough coins refused'); else fails := fails + 1; res := array_append(res, 'FAIL 12a ' || sqlerrm); end if; end;
  insert into public.kl_coin_ledger (user_id, amount, reason, ref) values (uid, 800, 'test_grant', 'test');
  r := public.buy_item('streak_freeze'); r := public.buy_item('streak_freeze');
  n := n + 1; if (r ->> 'freezes')::int = 2 and (r ->> 'balance')::int = bal0 + 800 - 300 then res := array_append(res, 'ok 12b two freezes bought, balance correct'); else fails := fails + 1; res := array_append(res, 'FAIL 12b ' || r::text); end if;
  begin perform public.buy_item('streak_freeze'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 12c third freeze accepted');
  exception when others then n := n + 1; if sqlerrm = 'freeze_limit' then res := array_append(res, 'ok 12c freeze limit (2)'); else fails := fails + 1; res := array_append(res, 'FAIL 12c ' || sqlerrm); end if; end;
  perform public.buy_item('theme_night');
  begin perform public.buy_item('theme_night'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 12d theme bought twice');
  exception when others then n := n + 1; if sqlerrm = 'already_owned' then res := array_append(res, 'ok 12d already_owned'); else fails := fails + 1; res := array_append(res, 'FAIL 12d ' || sqlerrm); end if; end;
  r := public.equip_item('theme_night');
  n := n + 1; if (r ->> 'equipped')::boolean then res := array_append(res, 'ok 12e theme equipped'); else fails := fails + 1; res := array_append(res, 'FAIL 12e'); end if;
  begin perform public.equip_item('theme_forest'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 12f equipped a theme not owned');
  exception when others then n := n + 1; if sqlerrm = 'not_owned' then res := array_append(res, 'ok 12f not_owned'); else fails := fails + 1; res := array_append(res, 'FAIL 12f ' || sqlerrm); end if; end;
  begin perform public.buy_item('nope'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 12g unknown item accepted');
  exception when others then n := n + 1; if sqlerrm = 'item_not_found' then res := array_append(res, 'ok 12g item_not_found'); else fails := fails + 1; res := array_append(res, 'FAIL 12g ' || sqlerrm); end if; end;

  -- 13 streak freeze saves one missed day; 4 missed days are too many
  update public.study_stats set current_streak = 5, last_active_date = today - 2 where user_id = uid;
  w := public.get_wallet();
  n := n + 1; if (w -> 'streak' ->> 'current')::int = 5 and (w -> 'streak' ->> 'protected')::boolean then res := array_append(res, 'ok 13a wallet shows the streak protected by a freeze');
  else fails := fails + 1; res := array_append(res, 'FAIL 13a ' || w::text); end if;
  perform public._touch_activity(uid, 1);
  w := public.get_wallet();
  n := n + 1; if (w -> 'streak' ->> 'current')::int = 6 and (w -> 'streak' ->> 'freezes')::int = 1 and (w -> 'streak' ->> 'freeze_used_today')::boolean then res := array_append(res, 'ok 13b freeze used: streak 6, 1 freeze left');
  else fails := fails + 1; res := array_append(res, 'FAIL 13b ' || w::text); end if;
  update public.study_stats set current_streak = 6, last_active_date = today - 5 where user_id = uid;
  perform public._touch_activity(uid, 1);
  w := public.get_wallet();
  n := n + 1; if (w -> 'streak' ->> 'current')::int = 1 and (w -> 'streak' ->> 'freezes')::int = 1 then res := array_append(res, 'ok 13c 4 missed days: streak restarts at 1, freeze kept');
  else fails := fails + 1; res := array_append(res, 'FAIL 13c ' || w::text); end if;

  -- 14 ledger is append-only
  begin update public.kl_coin_ledger set amount = 999 where user_id = uid; n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 14a ledger update allowed');
  exception when others then n := n + 1; if sqlerrm = 'ledger_is_append_only' then res := array_append(res, 'ok 14a ledger update refused'); else fails := fails + 1; res := array_append(res, 'FAIL 14a ' || sqlerrm); end if; end;
  begin delete from public.kl_coin_ledger where user_id = uid; n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 14b ledger delete allowed');
  exception when others then n := n + 1; if sqlerrm = 'ledger_is_append_only' then res := array_append(res, 'ok 14b ledger delete refused'); else fails := fails + 1; res := array_append(res, 'FAIL 14b ' || sqlerrm); end if; end;

  -- 15 a student cannot write coins directly
  begin
    execute 'set local role authenticated';
    insert into public.kl_coin_ledger (user_id, amount, reason, ref) values (uid, 999, 'hack', 'x');
    execute 'reset role'; n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 15 direct insert allowed');
  exception when others then
    msg := sqlerrm; execute 'reset role'; n := n + 1;
    if msg ilike '%permission denied%' or msg ilike '%row-level security%' then res := array_append(res, 'ok 15 direct coin insert refused');
    else fails := fails + 1; res := array_append(res, 'FAIL 15 ' || msg); end if;
  end;

  -- 16 bad story keys are rejected; a view is recorded
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'story_answer', 'payload', jsonb_build_object('story_key', 'qotd:2000-01-01', 'choice', 0))));
  n := n + 1; if r -> 0 ->> 'status' = 'rejected' and r -> 0 ->> 'message' = 'story_not_found' then res := array_append(res, 'ok 16a unknown story refused'); else fails := fails + 1; res := array_append(res, 'FAIL 16a ' || r::text); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'story_view', 'payload', jsonb_build_object('story_key', qkey))));
  n := n + 1; if r -> 0 ->> 'status' = 'applied' and exists (select 1 from jsonb_array_elements(public.get_my_stories() -> 'stories') e where e ->> 'key' = qkey and (e ->> 'seen')::boolean)
  then res := array_append(res, 'ok 16b story view saved, story now seen'); else fails := fails + 1; res := array_append(res, 'FAIL 16b ' || r::text); end if;

  -- 17 no login = no access
  perform set_config('request.jwt.claims', '', true); perform set_config('request.jwt.claim.sub', '', true);
  begin perform public.get_wallet(); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 17 wallet without login');
  exception when others then n := n + 1; if sqlerrm = 'not_authenticated' then res := array_append(res, 'ok 17 not_authenticated'); else fails := fails + 1; res := array_append(res, 'FAIL 17 ' || sqlerrm); end if; end;

  raise exception 'TEST RESULT (rolled back): % ;; %', case when fails = 0 then 'SUMMARY: ALL ' || n || ' PASSED' else 'SUMMARY: ' || fails || ' FAILED of ' || n end, array_to_string(res, ' ;; ');
end
$t34$;
