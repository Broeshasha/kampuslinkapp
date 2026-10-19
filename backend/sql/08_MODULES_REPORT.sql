-- =============================================================================
-- KAMPUSLINK BACKEND  |  08  WHAT MODULES EXIST? (read-only, 4 blocks)
-- =============================================================================
-- Run one block at a time, copy the JSON cell back to me.
-- Pilot cohort used below: Mining Engineering (speciality 2), year L2, university 6
-- (change the three numbers if you want another cohort).
-- =============================================================================


-- =============================================================================
-- M1  The modules a Mining L2 student at university 6 sees today
--     scope = 'speciality' (made for Mining) or 'domain' (shared by the whole domain)
-- =============================================================================
select coalesce(jsonb_agg(to_jsonb(x) order by x.semester nulls last, x.ue_category nulls last, x.name), '[]'::jsonb)
       as kampus_m1_modules
from (
  select m.id, m.semester, m.ue_category, m.name, m.university_id,
         case when m.speciality_id is not null then 'speciality' else 'domain' end as scope,
         (select count(*) from public.study_resources r where r.module_id = m.id) as files
  from public.study_modules m
  join public.specialities s on s.id = 2
  where m.academic_year = 'L2'
    and (m.speciality_id = 2 or (m.speciality_id is null and m.domain_id = s.domain_id))
    and (m.university_id is null or m.university_id = 6)
) x;


-- =============================================================================
-- M2  Overview: how many Mining modules exist per year and semester,
--     and how many are tied to one university
-- =============================================================================
select jsonb_build_object(
  'domain', (select jsonb_build_object('id', d.id, 'code', d.code, 'name', d.name)
             from public.specialities s join public.domains d on d.id = s.domain_id where s.id = 2),
  'by_year_semester', (
    select coalesce(jsonb_agg(to_jsonb(y) order by y.academic_year, y.semester nulls last), '[]'::jsonb)
    from (
      select m.academic_year, m.semester,
             count(*) as modules,
             count(*) filter (where m.speciality_id is not null) as speciality_modules,
             count(*) filter (where m.speciality_id is null)     as domain_modules,
             count(*) filter (where m.university_id is null)     as without_university,
             count(distinct m.university_id)                     as universities
      from public.study_modules m
      join public.specialities s on s.id = 2
      where m.speciality_id = 2 or (m.speciality_id is null and m.domain_id = s.domain_id)
      group by m.academic_year, m.semester
    ) y)
) as kampus_m2_overview;


-- =============================================================================
-- M3  Duplicates inside the student's module list (same name written twice)
-- =============================================================================
with mods as (
  select m.id, m.semester, m.name
  from public.study_modules m
  join public.specialities s on s.id = 2
  where m.academic_year = 'L2'
    and (m.speciality_id = 2 or (m.speciality_id is null and m.domain_id = s.domain_id))
    and (m.university_id is null or m.university_id = 6)
)
select coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb) as kampus_m3_duplicates
from (
  select lower(regexp_replace(trim(name), '\s+', ' ', 'g')) as normalized_name,
         count(*) as times, array_agg(id order by id) as module_ids
  from mods
  group by 1
  having count(*) > 1
) d;


-- =============================================================================
-- M4  Which languages do your students use? (decides how many translations each
--     chat message really needs; fewer languages = cheaper and faster)
-- =============================================================================
select jsonb_build_object(
  'all_onboarded_profiles', (
    select coalesce(jsonb_object_agg(preferred_language, n), '{}'::jsonb)
    from (select preferred_language, count(*) as n from public.profiles
          where onboarding_complete group by 1) a),
  'mining_L2_profiles', (
    select coalesce(jsonb_object_agg(preferred_language, n), '{}'::jsonb)
    from (select preferred_language, count(*) as n from public.profiles
          where speciality_id = 2 and academic_year = 'L2' group by 1) b)
) as kampus_m4_languages;
