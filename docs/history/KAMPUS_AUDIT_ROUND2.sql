-- =============================================================================
-- KAMPUSLINK BACKEND AUDIT - ROUND 2 (READ-ONLY)
-- Same rules as round 1: paste ONE block at a time, copy the single JSON cell back.
-- These only read. Block R1 automatically masks any "Bearer <token>" it finds.
-- =============================================================================


-- =============================================================================
-- R1  SCHEDULED JOBS (pg_cron is installed): who writes to your tables on a timer
-- =============================================================================
select coalesce(jsonb_agg(jsonb_build_object(
         'jobid', jobid,
         'name', jobname,
         'schedule', schedule,
         'active', active,
         'command', regexp_replace(command, 'Bearer\s+[A-Za-z0-9._~+/=-]+', 'Bearer XXX', 'g')
       ) order by jobid), '[]'::jsonb) as kampus_r1_cron
from cron.job;


-- =============================================================================
-- R2  VIEW SECURITY + OWNERS (are the Store views leaking customer data to anon?)
-- =============================================================================
select jsonb_build_object(
  'views', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'view', c.relname,
             'options', c.reloptions,
             'owner', pg_get_userbyid(c.relowner)
           ) order by c.relname), '[]'::jsonb)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'v'
  ),
  'tables_without_rls', (
    select coalesce(jsonb_agg(c.relname order by c.relname), '[]'::jsonb)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity
  )
) as kampus_r2_view_security;


-- =============================================================================
-- R3  MINING ENGINEERING, YEAR 2: the modules your first cohort will see
--     (speciality id 2 = "Mining Engineering" in the app's hard-coded list;
--      this block also checks that the DB agrees)
-- =============================================================================
select jsonb_build_object(
  'speciality_check', (
    select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
    from specialities s
    where s.id = 2 or s.name ilike '%min%'
  ),
  'modules_L2', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', m.id,
             'name', m.name,
             'semester', m.semester,
             'ue', m.ue_category,
             'university_id', m.university_id,
             'scope', case when m.speciality_id is not null then 'speciality' else 'domain' end,
             'resources', (select count(*) from study_resources r where r.module_id = m.id)
           ) order by m.semester, m.name), '[]'::jsonb)
    from study_modules m
    where m.academic_year = 'L2'
      and (m.speciality_id = 2
           or (m.speciality_id is null
               and m.domain_id = (select domain_id from specialities where id = 2)))
  ),
  'universities_with_mining_L2', (
    select coalesce(jsonb_agg(distinct m.university_id), '[]'::jsonb)
    from study_modules m
    where m.academic_year = 'L2' and m.speciality_id = 2
  )
) as kampus_r3_mining_l2;


-- =============================================================================
-- R4  RESOURCES BREAKDOWN: scraped vs student-uploaded (decides what the R2 wipe removes)
-- =============================================================================
select jsonb_build_object(
  'by_origin', (
    select coalesce(jsonb_agg(x), '[]'::jsonb)
    from (
      select (uploader_id is null) as scraped, file_format, resource_type, count(*) as n
      from study_resources
      group by 1, 2, 3
      order by 1, 2, 3
    ) x
  ),
  'student_uploads', (select count(*) from study_resources where uploader_id is not null),
  'distinct_uploaders', (select count(distinct uploader_id) from study_resources where uploader_id is not null),
  'resources_with_upvotes', (select count(*) from study_resources where upvote_count > 0),
  'resources_with_downloads', (select count(*) from study_resources where download_count > 0),
  'external_links_not_in_r2', (
    select count(*) from study_resources
    where file_urls::text not like '%files.kampus-link.com%'
  )
) as kampus_r4_resources;


-- =============================================================================
-- STILL NEEDED FROM THE DASHBOARDS (SQL cannot see these)
--   * Supabase -> Edge Functions: names, and the SOURCE of "send-push" (secrets removed)
--   * Cloudflare -> R2: bucket names + the list of top-level folders in each bucket
--     (we only know avatars, community, library, marketplace from the app and database;
--      Store product images may live in another folder)
--   * Cloudflare -> Workers: source of upload.kampus-link.com and order-submit (secrets removed)
--   * Whatever runs your scrapers (n8n, GitHub Actions, a server): names only, no keys
--   * Play Console: highest versionCode ever uploaded
-- =============================================================================
