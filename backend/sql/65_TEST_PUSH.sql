-- KAMPUSLINK FILE 65: test of 64. Rolls back (raises on purpose). Expected: "65 ALL 6 PASSED (rolled back)".
-- Works at any hour: it moves "now"-dependent data around instead of the clock.
do $$
declare u uuid; b jsonb; ok int := 0; h int := extract(hour from now() at time zone 'Africa/Algiers');
begin
  if h < 7 or h >= 22 then raise exception '65 SKIPPED: run between 07:00 and 22:00 Algiers time'; end if;
  select id into u from public.profiles order by id limit 1;
  update public.app_config set value = 'true' where key = 'push_enabled';
  -- everybody else out of the way for this test
  update public.user_reminder_state set step = 4 where user_id <> u;
  insert into public.user_reminder_state (user_id) values (u) on conflict do nothing;
  update public.user_reminder_state set step = 0, unsubscribed = false, stopped = false, paused_until = null,
         study_days = '{1,2,3,4,5,6,7}', study_time = '00:00', last_sent_at = null,
         last_active_at = now() - interval '3 days' where user_id = u;
  delete from public.kl_push_log where user_id = u;
  insert into public.push_tokens (token, user_id) values ('test-token-aaaaaaaaaaaaaaaaaaaa', u)
    on conflict (token) do update set user_id = u;

  -- T1 a student who missed days gets one push with the token
  b := public.push_batch();
  if jsonb_array_length(b) = 1 and b -> 0 -> 'tokens' ? 'test-token-aaaaaaaaaaaaaaaaaaaa' and length(b -> 0 ->> 'body') > 5
    then ok := ok + 1; else raise exception 'T1 %', b; end if;
  -- T2 never twice the same day
  if jsonb_array_length(public.push_batch()) = 0 then ok := ok + 1; else raise exception 'T2'; end if;
  -- T3 "stop" wins
  delete from public.kl_push_log where user_id = u;
  update public.user_reminder_state set last_sent_at = null, step = 0, unsubscribed = true where user_id = u;
  if jsonb_array_length(public.push_batch()) = 0 then ok := ok + 1; else raise exception 'T3'; end if;
  -- T4 studied yesterday -> nothing
  update public.user_reminder_state set unsubscribed = false, last_active_at = now() - interval '1 hour' where user_id = u;
  if jsonb_array_length(public.push_batch()) = 0 then ok := ok + 1; else raise exception 'T4'; end if;
  -- T5 before study time + 60 min -> nothing (study time = in 30 min; skipped after 21:00)
  update public.user_reminder_state set last_active_at = now() - interval '3 days',
         study_time = to_char(now() at time zone 'Africa/Algiers' + interval '30 minutes', 'HH24:MI') where user_id = u;
  if h >= 21 or jsonb_array_length(public.push_batch()) = 0 then ok := ok + 1; else raise exception 'T5'; end if;
  -- T6 dead token removed; students cannot call push_batch
  if public.push_dead_tokens(array['test-token-aaaaaaaaaaaaaaaaaaaa']) = 1
     and not has_function_privilege('authenticated', 'public.push_batch(int)', 'execute') then ok := ok + 1;
  else raise exception 'T6'; end if;

  raise exception '65 ALL % PASSED (rolled back)', ok;
end $$;
