-- =============================================================================
-- KAMPUSLINK BACKEND  |  06  FIXES FOUND IN THE FIRST RUN RESULTS
-- =============================================================================
-- Run block by block. Each one is small and safe to repeat.
-- =============================================================================


-- =============================================================================
-- F1  CLOSE THE PUSH HOLE (your C3 result still shows call_send_push open to anon)
--     Nothing calls this function any more (the notification triggers were dropped in
--     file 01), so revoking it now breaks nothing.
--     The service key written INSIDE it still has to be rotated: see runbook A5.
-- =============================================================================
revoke execute on function public.call_send_push(jsonb) from public, anon, authenticated;

-- check: must return false, false
select has_function_privilege('anon',          'public.call_send_push(jsonb)', 'execute') as anon_can_call,
       has_function_privilege('authenticated', 'public.call_send_push(jsonb)', 'execute') as authenticated_can_call;


-- =============================================================================
-- F2  RUNBOOK A4 LEFTOVERS: your C4 shows domains with 0 policies, so the A4 block was not
--     (fully) run. Idempotent: safe even if it was.
-- =============================================================================
alter table public.domains enable row level security;
drop policy if exists "domains read" on public.domains;
create policy "domains read" on public.domains for select to anon, authenticated using (true);
alter table public.kampus_store_import_queue enable row level security;   -- no policy: service role only

-- check: every table below must show rls = true
select relname as table_name, relrowsecurity as rls
from pg_class
where relnamespace = 'public'::regnamespace and relkind = 'r'
  and relname in ('advertiser_picks','advertiser_stores','domains','kampus_store_import_queue',
                  'ks_settings','ref_clicks','universities','push_tokens')
order by relname;
-- If ANY row says false (especially advertiser_stores, a Store table that was not in the
-- first audit): tell me before touching it. A table with row security off and no policy is
-- readable and writable by anyone who has your anon key.


-- =============================================================================
-- F3  public_profiles must show only students who finished the NEW onboarding.
--     Your test data has old profiles marked onboarding_complete = true without year or
--     section (one even uses an email address as username). They must not appear in chat.
-- =============================================================================
create or replace view public.public_profiles as
select p.id, p.username, p.avatar_url, p.avatar_blurhash,
       p.university_id, p.speciality_id, p.academic_year, p.created_at
from public.profiles p
where p.onboarding_complete and p.onboarding_version >= 1;

revoke all on public.public_profiles from anon, authenticated;
grant select on public.public_profiles to authenticated;
-- RULE FOR THE NEW APP: a profile counts as onboarded only when onboarding_version >= 1.
-- Everyone from the old app has 0, so they see the new onboarding once, keep their account.


-- =============================================================================
-- F4  OPTIONAL, STORE SIDE (do only after the Store sync is confirmed to use the service
--     role key). apply_sync and set_costs are open to anon; row security stops them from
--     changing anything today, but they should not be callable at all.
-- =============================================================================
-- revoke execute on function public.apply_sync(jsonb) from public, anon, authenticated;
-- revoke execute on function public.set_costs(jsonb)  from public, anon, authenticated;
