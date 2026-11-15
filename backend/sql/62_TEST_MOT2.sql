-- KAMPUSLINK FILE 62: test of 61. Read-only: everything rolls back at the end (it raises on purpose).
-- Run AFTER 61. Expected last line: "62 ALL 6 PASSED (rolled back)".
do $$
declare u uuid; r jsonb; w jsonb; lm date; ok int := 0; failed text;
begin
  select id into u from public.profiles order by id limit 1;
  if u is null then raise exception 'no profile to test with'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
  insert into public.study_stats (user_id, xp) values (u, 1000) on conflict (user_id) do update set xp = public.study_stats.xp + 1000;
  update public.kl_user_streak set week_freezes = 0 where user_id = u;
  delete from public.kl_week_freeze_used where user_id = u;
  lm := (date_trunc('week', public.algiers_today()::timestamp)::date) - 7;

  -- T1 buy one freeze
  r := public.buy_item('week_freeze');
  if (r ->> 'freezes')::int = 1 then ok := ok + 1; else raise exception 'T1 %', r; end if;
  -- T2 max 2 held
  perform public.buy_item('week_freeze');
  begin perform public.buy_item('week_freeze'); failed := 'no error';
  exception when others then failed := sqlerrm; end;
  if failed = 'freeze_limit' then ok := ok + 1; else raise exception 'T2 %', failed; end if;
  -- T3 wallet shows it
  w := public.get_wallet();
  if (w ->> 'week_freezes')::int = 2 and (w ->> 'max_week_freezes')::int = 2 then ok := ok + 1; else raise exception 'T3 %', w; end if;
  -- T4 use on last week, twice = one freeze spent
  r := public.use_week_freeze(lm); r := public.use_week_freeze(lm);
  if (r ->> 'used')::boolean and (r ->> 'week_freezes')::int = 1 then ok := ok + 1; else raise exception 'T4 %', r; end if;
  -- T5 only last week
  begin perform public.use_week_freeze(lm - 7); failed := 'no error';
  exception when others then failed := sqlerrm; end;
  if failed = 'bad_week' then ok := ok + 1; else raise exception 'T5 %', failed; end if;
  -- T6 frozen week listed; streak freeze still works
  w := public.get_wallet();
  r := public.buy_item('streak_freeze');
  if (w -> 'frozen_weeks') ->> 0 = lm::text and r ? 'freezes' then ok := ok + 1; else raise exception 'T6 % %', w, r; end if;

  raise exception '62 ALL % PASSED (rolled back)', ok;
end $$;
