-- KAMPUSLINK FILE 38: test of file 37 (shop v2). Safe: everything is rolled back at the end.
do $t38$
declare
  uid uuid := '322af894-2767-4a2c-8b1f-03a83b0590d0';
  res text[] := '{}'; fails int := 0; n int := 0; r jsonb; w jsonb; today date := public.algiers_today();
begin
  perform set_config('request.jwt.claim.sub', uid::text, true);
  update public.profiles set speciality_id = 2, academic_year = 'L2' where id = uid;
  delete from public.kl_user_helpers where user_id = uid;
  delete from public.kl_user_extras where user_id = uid;
  delete from public.kl_user_inventory where user_id = uid;
  update public.kl_user_streak set last_repair_on = null where user_id = uid;
  insert into public.study_stats (user_id) values (uid) on conflict do nothing;
  insert into public.kl_coin_ledger (user_id, amount, reason, ref) values (uid, 10000, 'test_grant', 'test38');

  -- 1 helpers stack and are used through sync (one per op), never below 0
  perform public.buy_item('pack_5050'); perform public.buy_item('pack_5050');
  n := n + 1; if (public.get_wallet() -> 'helpers' ->> 'fifty_fifty')::int = 10 then res := array_append(res, 'ok 1a two 50/50 packs = 10 uses');
  else fails := fails + 1; res := array_append(res, 'FAIL 1a ' || (public.get_wallet() -> 'helpers')::text); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'helper_use', 'payload', '{"helper":"fifty_fifty"}'::jsonb)));
  n := n + 1; if r -> 0 ->> 'status' = 'applied' and (public.get_wallet() -> 'helpers' ->> 'fifty_fifty')::int = 9 then res := array_append(res, 'ok 1b one use = 9 left');
  else fails := fails + 1; res := array_append(res, 'FAIL 1b ' || r::text); end if;
  r := public.sync_progress(jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'helper_use', 'payload', '{"helper":"hint"}'::jsonb)));
  n := n + 1; if r -> 0 ->> 'status' = 'rejected' and r -> 0 ->> 'message' = 'no_helper' then res := array_append(res, 'ok 1c no hints owned = rejected');
  else fails := fails + 1; res := array_append(res, 'FAIL 1c ' || r::text); end if;

  -- 2 custom header: must own it; text checked
  begin perform public.set_header_text('Ahmed Lab'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 2a header without buying');
  exception when others then n := n + 1; if sqlerrm = 'not_owned' then res := array_append(res, 'ok 2a not_owned'); else fails := fails + 1; res := array_append(res, 'FAIL 2a ' || sqlerrm); end if; end;
  perform public.buy_item('custom_header');
  r := public.set_header_text('  Ahmed   Lab ');
  n := n + 1; if r ->> 'header_text' = 'Ahmed Lab' and public.get_wallet() ->> 'header_text' = 'Ahmed Lab' then res := array_append(res, 'ok 2b header saved and cleaned');
  else fails := fails + 1; res := array_append(res, 'FAIL 2b ' || r::text); end if;
  r := public.set_header_text('مختبر أحمد');
  n := n + 1; if r ->> 'header_text' = 'مختبر أحمد' then res := array_append(res, 'ok 2c Arabic text ok'); else fails := fails + 1; res := array_append(res, 'FAIL 2c'); end if;
  begin perform public.set_header_text('http://spam.com'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 2d link accepted');
  exception when others then n := n + 1; if sqlerrm = 'invalid_text' then res := array_append(res, 'ok 2d links refused'); else fails := fails + 1; res := array_append(res, 'FAIL 2d ' || sqlerrm); end if; end;
  insert into public.kl_blocked_words (word) values ('badword') on conflict do nothing;
  begin perform public.set_header_text('my BadWord'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 2e blocked word accepted');
  exception when others then n := n + 1; if sqlerrm = 'blocked_text' then res := array_append(res, 'ok 2e blocked word refused'); else fails := fails + 1; res := array_append(res, 'FAIL 2e ' || sqlerrm); end if; end;

  -- 3 earned items cannot be bought; they come from achievements
  begin perform public.buy_item('frame_streak_30'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 3a earned item bought');
  exception when others then n := n + 1; if sqlerrm = 'not_for_sale' then res := array_append(res, 'ok 3a not_for_sale'); else fails := fails + 1; res := array_append(res, 'FAIL 3a ' || sqlerrm); end if; end;
  perform public._note_achievement(uid, 'streak', 'streak:30:test', '{"days":30}');
  perform public._note_achievement(uid, 'exam', 'attempt:test-ace', '{"score_20":18.5}');
  n := n + 1; if exists (select 1 from public.kl_user_inventory where user_id = uid and item_id = 'frame_streak_30')
     and exists (select 1 from public.kl_user_inventory where user_id = uid and item_id = 'title_streak_30')
     and exists (select 1 from public.kl_user_inventory where user_id = uid and item_id = 'title_exam_ace')
  then res := array_append(res, 'ok 3b 30-day frame + title and exam ace granted'); else fails := fails + 1; res := array_append(res, 'FAIL 3b'); end if;

  -- 4 streak repair: only after missing exactly yesterday, once a month
  update public.study_stats set current_streak = 9, last_active_date = today - 5 where user_id = uid;
  begin perform public.buy_item('streak_repair'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 4a repaired an old streak');
  exception when others then n := n + 1; if sqlerrm = 'nothing_to_repair' then res := array_append(res, 'ok 4a nothing_to_repair'); else fails := fails + 1; res := array_append(res, 'FAIL 4a ' || sqlerrm); end if; end;
  update public.study_stats set current_streak = 9, last_active_date = today - 2 where user_id = uid;
  update public.kl_user_streak set freezes = 0 where user_id = uid;
  perform public.buy_item('streak_repair');
  w := public.get_wallet();
  n := n + 1; if (w -> 'streak' ->> 'current')::int = 9 then res := array_append(res, 'ok 4b streak 9 is back');
  else fails := fails + 1; res := array_append(res, 'FAIL 4b ' || (w -> 'streak')::text); end if;
  update public.study_stats set last_active_date = today - 2 where user_id = uid;
  begin perform public.buy_item('streak_repair'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 4c second repair same month');
  exception when others then n := n + 1; if sqlerrm = 'repair_cooldown' then res := array_append(res, 'ok 4c once a month'); else fails := fails + 1; res := array_append(res, 'FAIL 4c ' || sqlerrm); end if; end;

  -- 5 the wallet carries the look of owned items (card skin colours)
  perform public.buy_item('skin_night'); perform public.equip_item('skin_night');
  n := n + 1; if exists (select 1 from jsonb_array_elements(public.get_wallet() -> 'inventory') e
                         where e ->> 'item_id' = 'skin_night' and (e ->> 'equipped')::boolean and e -> 'payload' -> 'bg' is not null)
  then res := array_append(res, 'ok 5 equipped card skin with its colours'); else fails := fails + 1; res := array_append(res, 'FAIL 5'); end if;

  raise exception 'TEST RESULT (rolled back): % ;; %', case when fails = 0 then 'SUMMARY: ALL ' || n || ' PASSED' else 'SUMMARY: ' || fails || ' FAILED of ' || n end, array_to_string(res, ' ;; ');
end
$t38$;
