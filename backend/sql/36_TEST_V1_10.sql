-- KAMPUSLINK FILE 36: test of file 35 (achievement posts, shop items). Safe: everything is rolled back at the end.
-- Uses the test student + ONE other existing student (temporarily moved into the same class, rolled back).
do $t36$
declare
  uid uuid := '322af894-2767-4a2c-8b1f-03a83b0590d0'; other uuid;
  res text[] := '{}'; fails int := 0; n int := 0;
  r jsonb; s jsonb; lid bigint; aid bigint; pid uuid; opid uuid; c int; today date := public.algiers_today(); msg text;
begin
  perform set_config('request.jwt.claim.sub', uid::text, true);
  update public.profiles set username = 'test_user_a1', speciality_id = 2, academic_year = 'L2', study_goal_minutes = 5 where id = uid;
  delete from public.kl_story_posts where user_id = uid;
  select id into other from public.profiles where id <> uid order by created_at limit 1;
  if other is null then raise exception 'TEST RESULT (rolled back): needs one other student in profiles'; end if;
  update public.profiles set speciality_id = 2, academic_year = 'L2', username = coalesce(username, 'classmate_x') where id = other;
  delete from public.blocked_users where (blocker_id = uid and blocked_id = other) or (blocker_id = other and blocked_id = uid);

  -- 1 shop has frames, titles and more themes
  n := n + 1; if (select count(*) from public.kl_shop_items where active) >= 17 and exists (select 1 from public.kl_shop_items where kind = 'frame')
     and exists (select 1 from public.kl_shop_items where kind = 'title') then res := array_append(res, 'ok 1 shop: themes, frames, titles');
  else fails := fails + 1; res := array_append(res, 'FAIL 1 shop items'); end if;

  -- 2 a finished lesson becomes an achievement even when the coin cap is reached
  update public.app_config set value = '0'::jsonb where key = 'coins_daily_cap';
  select l.id into lid from public.learn_lessons l where l.status = 'published' and l.module_id in (select t.id from public.my_module_ids() as t(id)) order by l.id limit 1;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'lesson_done', 'payload', jsonb_build_object('lesson_id', lid, 'score', 80))));
  select a.id into aid from public.kl_achievements a where a.user_id = uid and a.kind = 'lesson_done' and a.ref = 'lesson:' || lid;
  n := n + 1; if aid is not null and (r -> 0 ->> 'coins')::int = 0 then res := array_append(res, 'ok 2 achievement recorded with 0 coins (cap)');
  else fails := fails + 1; res := array_append(res, 'FAIL 2 ' || r::text); end if;
  update public.app_config set value = '100'::jsonb where key = 'coins_daily_cap';

  -- 3 it is offered in get_my_stories.postable and "me" is there
  s := public.get_my_stories();
  n := n + 1; if exists (select 1 from jsonb_array_elements(s -> 'postable') e where (e ->> 'achievement_id')::bigint = aid) and s -> 'me' ->> 'username' = 'test_user_a1'
  then res := array_append(res, 'ok 3 postable + me'); else fails := fails + 1; res := array_append(res, 'FAIL 3 ' || (s -> 'postable')::text); end if;

  -- 4 post it once; twice = already_posted; it shows as my story
  r := public.post_achievement(aid); pid := (r ->> 'post_id')::uuid;
  begin perform public.post_achievement(aid); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 4a posted twice');
  exception when others then n := n + 1; if sqlerrm = 'already_posted' then res := array_append(res, 'ok 4a one post per achievement'); else fails := fails + 1; res := array_append(res, 'FAIL 4a ' || sqlerrm); end if; end;
  n := n + 1; if exists (select 1 from jsonb_array_elements(public.get_my_stories() -> 'stories') e where e ->> 'key' = 'post:' || pid and e ->> 'source' = 'mine')
     and not exists (select 1 from jsonb_array_elements(public.get_my_stories() -> 'postable') e where (e ->> 'achievement_id')::bigint = aid)
  then res := array_append(res, 'ok 4b my post shows, no longer offered'); else fails := fails + 1; res := array_append(res, 'FAIL 4b'); end if;

  -- 5 a classmate's post shows with their name; a block hides it both ways
  insert into public.kl_achievements (user_id, kind, ref, payload) values (other, 'streak', 'streak:7:test', '{"days":7}') returning id into aid;
  insert into public.kl_story_posts (user_id, achievement_id, kind, payload, speciality_id, academic_year)
  values (other, aid, 'streak', '{"days":7}', 2, 'L2') returning id into opid;
  n := n + 1; if exists (select 1 from jsonb_array_elements(public.get_my_stories() -> 'stories') e
                         where e ->> 'key' = 'post:' || opid and e ->> 'source' = 'post' and e -> 'payload' -> 'author' ->> 'id' = other::text)
  then res := array_append(res, 'ok 5a classmate post visible with author'); else fails := fails + 1; res := array_append(res, 'FAIL 5a'); end if;
  insert into public.blocked_users (blocker_id, blocked_id) values (uid, other);
  n := n + 1; if not exists (select 1 from jsonb_array_elements(public.get_my_stories() -> 'stories') e where e ->> 'key' = 'post:' || opid)
  then res := array_append(res, 'ok 5b blocked: hidden'); else fails := fails + 1; res := array_append(res, 'FAIL 5b'); end if;
  delete from public.blocked_users where blocker_id = uid and blocked_id = other;
  update public.profiles set academic_year = 'L3' where id = other;
  update public.kl_story_posts set academic_year = 'L3' where id = opid;
  n := n + 1; if not exists (select 1 from jsonb_array_elements(public.get_my_stories() -> 'stories') e where e ->> 'key' = 'post:' || opid)
  then res := array_append(res, 'ok 5c other class: not visible'); else fails := fails + 1; res := array_append(res, 'FAIL 5c'); end if;
  update public.kl_story_posts set academic_year = 'L2' where id = opid;

  -- 6 reporting hides (threshold set to 1 for the test); delete only my own
  update public.app_config set value = '1'::jsonb where key = 'post_reports_hide';
  perform public.report_post(opid);
  n := n + 1; if (select hidden from public.kl_story_posts where id = opid) then res := array_append(res, 'ok 6a reported post hidden'); else fails := fails + 1; res := array_append(res, 'FAIL 6a'); end if;
  begin perform public.delete_my_post(opid); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 6b deleted someone else''s post');
  exception when others then n := n + 1; if sqlerrm = 'not_found' then res := array_append(res, 'ok 6b cannot delete others'); else fails := fails + 1; res := array_append(res, 'FAIL 6b ' || sqlerrm); end if; end;
  perform public.delete_my_post(pid);
  n := n + 1; if not exists (select 1 from public.kl_story_posts where id = pid) then res := array_append(res, 'ok 6c my post deleted'); else fails := fails + 1; res := array_append(res, 'FAIL 6c'); end if;

  -- 7 low exam score not offered; daily post limit
  insert into public.kl_achievements (user_id, kind, ref, payload) values (uid, 'exam', 'attempt:test-low', '{"score_20":8}') returning id into aid;
  n := n + 1; if not exists (select 1 from jsonb_array_elements(public.get_my_achievements()) e where (e ->> 'achievement_id')::bigint = aid)
  then res := array_append(res, 'ok 7a exam under 10/20 not offered'); else fails := fails + 1; res := array_append(res, 'FAIL 7a'); end if;
  update public.app_config set value = '0'::jsonb where key = 'posts_per_day';
  insert into public.kl_achievements (user_id, kind, ref, payload) values (uid, 'daily_goal', 'day:test', '{"minutes":40}') returning id into aid;
  begin perform public.post_achievement(aid); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 7b limit ignored');
  exception when others then n := n + 1; if sqlerrm = 'daily_limit' then res := array_append(res, 'ok 7b daily limit'); else fails := fails + 1; res := array_append(res, 'FAIL 7b ' || sqlerrm); end if; end;
  update public.app_config set value = '5'::jsonb where key = 'posts_per_day';

  -- 8 streak 3 -> achievement
  update public.study_stats set current_streak = 2, last_active_date = today - 1 where user_id = uid;
  perform public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 300))));
  n := n + 1; if exists (select 1 from public.kl_achievements where user_id = uid and kind = 'streak' and payload ->> 'days' = '3')
  then res := array_append(res, 'ok 8 streak 3 recorded'); else fails := fails + 1; res := array_append(res, 'FAIL 8'); end if;

  -- 9 equipped title + frame appear on my author card
  insert into public.kl_coin_ledger (user_id, amount, reason, ref) values (uid, 5000, 'test_grant', 'test36');
  perform public.buy_item('title_night_owl'); perform public.equip_item('title_night_owl');
  perform public.buy_item('frame_fire'); perform public.equip_item('frame_fire');
  s := public.get_my_stories() -> 'me';
  n := n + 1; if s -> 'title' ->> 'en' = 'Night owl' and jsonb_array_length(s -> 'frame') = 2 then res := array_append(res, 'ok 9 title + frame on my card');
  else fails := fails + 1; res := array_append(res, 'FAIL 9 ' || s::text); end if;

  raise exception 'TEST RESULT (rolled back): % ;; %', case when fails = 0 then 'SUMMARY: ALL ' || n || ' PASSED' else 'SUMMARY: ' || fails || ' FAILED of ' || n end, array_to_string(res, ' ;; ');
end
$t36$;
