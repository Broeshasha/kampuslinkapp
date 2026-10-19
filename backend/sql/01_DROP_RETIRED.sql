-- =============================================================================
-- KAMPUSLINK BACKEND  |  01  DROP EVERYTHING RETIRED
-- =============================================================================
-- RUN ORDER OF THE WHOLE BACKEND:  01 drop  ->  02 schema  ->  03 functions
--                                  ->  04 security  ->  05 checks
-- Paste ONE BATCH at a time (a batch = the block between two "BATCH" headers).
-- After every batch: run the Store check (runbook A7). If a batch errors, STOP and send
-- me the exact error. Nothing here uses CASCADE on purpose: a hidden dependency must
-- show up as an error, not get deleted silently.
--
-- NEVER TOUCHED BY THIS FILE (Kampus Store + shared):
--   advertisers, advertiser_payouts, advertiser_picks, kampus_store_*, ks_settings,
--   ref_clicks, store_products_public, pending_kampus_store_orders, wilayas, dz_communes,
--   profiles, auth.users, universities, specialities, domains, study_modules, and every
--   admin_* / ks_* / get_my_* (no-argument) / register_advertiser / update_my_profile /
--   toggle_my_pick / apply_sync / set_costs / set_product_slug / protect_is_admin /
--   handle_new_user function.
-- =============================================================================


-- =============================================================================
-- BATCH 0  GUARD (must pass before anything else)
-- =============================================================================
do $$
begin
  if not exists (select 1 from information_schema.schemata where schema_name like 'archive\_%') then
    raise exception 'STOP: no archive_ schema found. Do runbook step A2 (archive copy) first.';
  end if;
  if not exists (
    select 1 from information_schema.tables
    where table_schema like 'archive\_%' and table_name = 'study_resources'
  ) then
    raise exception 'STOP: archive exists but study_resources is not in it. Redo step A2.';
  end if;
end $$;


-- =============================================================================
-- BATCH 1  TRIGGERS, NOTIFICATION FUNCTIONS, RETIRED RPCs
-- (Before this: stop the cron jobs / scrapers that feed these tables, runbook B1)
-- =============================================================================
drop trigger if exists on_comment_like      on public.comment_likes;
drop trigger if exists on_community_comment on public.community_comments;
drop trigger if exists on_community_like    on public.community_likes;
drop trigger if exists on_new_message       on public.messages;
drop trigger if exists on_new_post          on public.posts;

drop function if exists public.trg_notify_like();
drop function if exists public.trg_notify_comment();
drop function if exists public.trg_notify_comment_like();
drop function if exists public.trg_notify_message();
drop function if exists public.trg_notify_new_post();

drop function if exists public.get_home_feed(uuid, integer);
drop function if exists public.get_campus_now_posts(uuid);
drop function if exists public.get_campus_now_fallback(uuid, integer);
drop function if exists public.get_community_feed(uuid, integer);
drop function if exists public.get_message_threads(uuid);
drop function if exists public.get_post_comments(uuid, uuid);
drop function if exists public.get_news_post_comments(uuid, uuid);
drop function if exists public.get_user_posts(uuid, uuid);
drop function if exists public.get_user_profile(uuid, uuid);
-- old student-profile RPC (the v1 replacement is get_me(), created in file 03).
-- NOTE: the no-argument get_my_profile() belongs to the Store partner portal: NOT dropped.
drop function if exists public.get_my_profile(uuid);


-- =============================================================================
-- BATCH 2  NEWS + COMMUNITY TABLES (leaf first)
-- =============================================================================
drop table if exists public.comment_likes;
drop table if exists public.community_comments;
drop table if exists public.community_likes;
drop table if exists public.community_posts;
drop table if exists public.post_comment_likes;
drop table if exists public.post_comments;
drop table if exists public.post_likes;
drop table if exists public.posts;


-- =============================================================================
-- BATCH 3  STUDENT MARKETPLACE + DIRECT MESSAGES
-- ONLY after runbook B0: the Kampus Store code has zero hits for marketplace_listings
-- and messages. (The database already shows no Store table linked to them.)
-- =============================================================================
drop table if exists public.messages;
drop table if exists public.marketplace_listings;


-- =============================================================================
-- BATCH 4  FEED EXTRAS, LOCATION TABLES, ONBOARDING LEFTOVERS, SCRAPER TABLES
-- =============================================================================
drop table if exists public.dining_menus;
drop table if exists public.meal_schedule;
drop table if exists public.exchange_rates;
drop table if exists public.missing_entry_suggestions;   -- onboarding no longer asks for it
drop table if exists public.countries;                    -- dead mirror of a hard-coded list

-- onboarding no longer asks for a residence or news interests
alter table public.profiles drop column if exists residence_id;
alter table public.profiles drop column if exists interest_sectors;
drop table if exists public.residences;
drop table if exists public.dous;

-- old scraper helpers (stop the scraper first, runbook B1)
drop view if exists public.modules_needing_enrichment;
drop view if exists public.modules_needing_resources;
drop view if exists public.modules_without_resources;
drop function if exists public.get_modules_needing_enrichment(integer);
drop function if exists public.get_unresourced_modules(integer);
drop table if exists public.scrape_sources_staging;
drop table if exists public.scrape_sources;


-- =============================================================================
-- BATCH 5  WIPE THE OLD LIBRARY ROWS AND OLD NOTIFICATIONS
-- (the R2 files are wiped later in runbook phase D; rows go first so nothing points at
--  a deleted file)
-- =============================================================================
delete from public.study_resources;                     -- the ~3,786 scraped rows
alter sequence public.study_resources_id_seq restart with 1;
delete from public.notifications;                        -- old like/comment/message types


-- =============================================================================
-- BATCH 6  HARDENING OF LEFTOVER FUNCTIONS
-- bump_academic_years is a yearly job, never a client call.
-- is_username_taken is only needed after sign-in.
-- =============================================================================
revoke execute on function public.bump_academic_years() from public, anon, authenticated;
revoke execute on function public.is_username_taken(text) from public, anon;
grant  execute on function public.is_username_taken(text) to authenticated;

-- (delete_my_account is rewritten in file 03; until then it still names dropped tables,
--  so do not test account deletion between 01 and 03)


-- =============================================================================
-- WHAT SHOULD BE LEFT (run after batch 6; compare with the list in the runbook, B8)
-- =============================================================================
select table_name, table_type
from information_schema.tables
where table_schema = 'public'
order by table_type, table_name;
