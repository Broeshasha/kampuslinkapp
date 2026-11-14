-- KAMPUSLINK FILE 41: B00 steps 1-2. Remove public.call_send_push: its text holds the leaked legacy service key.
-- Dropping it removes the text from the database; the key itself keeps working until the legacy keys are
-- switched off (B00 step 6). Stops with an error and changes nothing if anything still calls it.
do $b00$
declare n_fn int; n_trg int; n_cron int; f regprocedure;
begin
  select count(*) into n_fn from pg_proc
   where prosrc ilike '%call_send_push%' and proname <> 'call_send_push';
  select count(*) into n_trg from pg_trigger t join pg_proc p on p.oid = t.tgfoid
   where p.proname = 'call_send_push';
  n_cron := 0;
  if to_regclass('cron.job') is not null then
    execute $q$select count(*) from cron.job where command ilike '%call_send_push%'$q$ into n_cron;
  end if;
  if n_fn + n_trg + n_cron > 0 then
    raise exception 'STOP: call_send_push is still used (functions %, triggers %, cron jobs %). Nothing changed.', n_fn, n_trg, n_cron;
  end if;
  for f in select p.oid::regprocedure from pg_proc p
            where p.proname = 'call_send_push' and p.pronamespace = 'public'::regnamespace loop
    execute 'drop function ' || f::text;
  end loop;
end $b00$;

-- Report (counts only, never the text): where else could a key be written in the database?
select (select count(*) from pg_proc where proname = 'call_send_push') as call_send_push_left,
       (select count(*) from pg_proc p where p.prosrc ~ 'eyJhbGci[A-Za-z0-9_-]{20,}' or p.prosrc ilike '%sb_secret_%') as functions_with_a_key,
       (select count(*) from cron.job where command ~ 'eyJhbGci[A-Za-z0-9_-]{20,}' or command ilike '%sb_secret_%') as cron_jobs_with_a_key;