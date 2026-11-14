-- KAMPUSLINK FILE 40: test of file 39 (XP shop). Safe: everything is rolled back at the end.
-- Rebuilt on 2026-11-14 (the original was lost before commit). Uses the founder's test account.
do $t40$
declare
  uid uuid := '322af894-2767-4a2c-8b1f-03a83b0590d0';
  res text[] := '{}'; fails int := 0; n int := 0; r jsonb; w jsonb; xp0 bigint;
begin
  perform set_config('request.jwt.claim.sub', uid::text, true);
  insert into public.study_stats (user_id) values (uid) on conflict do nothing;
  update public.study_stats set xp = 500 where user_id = uid;
  delete from public.kl_xp_spend where user_id = uid;
  delete from public.kl_user_inventory where user_id = uid and item_id in ('theme_night', 'theme_forest');

  -- 1 wallet: balance = xp, old coin fields are 0
  w := public.get_wallet();
  n := n + 1; if (w ->> 'balance')::int = 500 and (w ->> 'xp_total')::int = 500 and (w ->> 'xp_spent')::int = 0
     and (w ->> 'today_earned')::int = 0 and (w ->> 'daily_cap')::int = 0
  then res := array_append(res, 'ok 1 wallet = 500 XP, old fields 0'); else fails := fails + 1; res := array_append(res, 'FAIL 1 ' || w::text); end if;

  -- 2 buying charges XP; XP itself does not go down
  r := public.buy_item('theme_night');
  w := public.get_wallet();
  n := n + 1; if (r ->> 'balance')::int = 100 and (w ->> 'balance')::int = 100 and (w ->> 'xp_spent')::int = 400
     and (select xp from public.study_stats where user_id = uid) = 500
  then res := array_append(res, 'ok 2 bought 400: balance 100, xp still 500'); else fails := fails + 1; res := array_append(res, 'FAIL 2 ' || w::text); end if;

  -- 3 not enough XP
  begin perform public.buy_item('theme_forest'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 3 bought without XP');
  exception when others then n := n + 1; if sqlerrm = 'insufficient_xp' then res := array_append(res, 'ok 3 insufficient_xp'); else fails := fails + 1; res := array_append(res, 'FAIL 3 ' || sqlerrm); end if; end;

  -- 4 cannot buy twice
  begin perform public.buy_item('theme_night'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 4 bought twice');
  exception when others then n := n + 1; if sqlerrm = 'already_owned' then res := array_append(res, 'ok 4 already_owned'); else fails := fails + 1; res := array_append(res, 'FAIL 4 ' || sqlerrm); end if; end;

  -- 5 unknown item
  begin perform public.buy_item('no_such_item'); n := n + 1; fails := fails + 1; res := array_append(res, 'FAIL 5 unknown item bought');
  exception when others then n := n + 1; if sqlerrm = 'item_not_found' then res := array_append(res, 'ok 5 item_not_found'); else fails := fails + 1; res := array_append(res, 'FAIL 5 ' || sqlerrm); end if; end;

  -- 6 old app versions: story ops are accepted and change nothing
  xp0 := (public.get_wallet() ->> 'balance')::int;
  r := public.sync_progress(jsonb_build_array(
         jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'story_answer', 'payload', '{"story_id":1,"choice":0}'::jsonb),
         jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'story_view',   'payload', '{"story_id":1}'::jsonb)));
  n := n + 1; if r -> 0 ->> 'status' = 'applied' and r -> 1 ->> 'status' = 'applied'
     and coalesce((r -> 0 ->> 'coins')::int, 0) = 0 and (public.get_wallet() ->> 'balance')::int = xp0
  then res := array_append(res, 'ok 6 story ops accepted as no-ops'); else fails := fails + 1; res := array_append(res, 'FAIL 6 ' || r::text); end if;

  -- 7 security: anon cannot call the shop, nobody can call _xp_balance directly
  n := n + 1; if not has_function_privilege('anon', 'public.buy_item(text)', 'execute')
     and not has_function_privilege('anon', 'public.get_wallet()', 'execute')
     and not has_function_privilege('authenticated', 'public._xp_balance(uuid)', 'execute')
     and has_function_privilege('authenticated', 'public.buy_item(text)', 'execute')
  then res := array_append(res, 'ok 7 grants'); else fails := fails + 1; res := array_append(res, 'FAIL 7 grants'); end if;

  -- 8 coin tables are gone, backup is kept
  n := n + 1; if to_regclass('public.kl_coin_ledger') is null and exists (select 1 from pg_namespace where nspname = 'kl_backup_1113')
  then res := array_append(res, 'ok 8 coin ledger dropped, backup kept'); else fails := fails + 1; res := array_append(res, 'FAIL 8'); end if;

  raise exception 'TEST RESULT (rolled back): % ;; %', case when fails = 0 then 'SUMMARY: ALL ' || n || ' PASSED' else 'SUMMARY: ' || fails || ' FAILED of ' || n end, array_to_string(res, ' ;; ');
end $t40$;