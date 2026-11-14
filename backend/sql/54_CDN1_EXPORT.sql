-- =====================================================================
-- 54_CDN1_EXPORT.sql  (FIX_PLAN 3.1 / CDN-1). Safe to re-run. Changes NOTHING for students.
-- 1) module_content_versions gets cdn_path + cdn_version (empty until a module is published to R2).
-- 2) cdn_module_export(module): the whole published content of a module as ONE json, built with the SAME
--    functions the app's downloads use today (_lesson_json, _practice_json, _filter_langs_deep). All languages.
--    For the importer machine only (service_role). Hidden cards/questions/sets/practice/exams are left out.
-- 3) cdn_set_path(module, version, path): the LAST step of a publish. Refused if the module changed since the
--    export (version moved) - phones then keep using Supabase until the next publish.
-- Students see nothing until CDN-2 (app) reads cdn_path from the catalog.
-- =====================================================================
alter table public.module_content_versions add column if not exists cdn_path text;
alter table public.module_content_versions add column if not exists cdn_version integer;

create or replace function public.cdn_module_export(p_module bigint)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'schema', 1,
    'module_id', m.id,
    'version', coalesce((select v.version from public.module_content_versions v where v.module_id = m.id), 0),
    'module', jsonb_build_object(
      'id', m.id,
      'name', coalesce((select x.display_name from public.kl_module_meta x where x.module_id = m.id), m.name),
      'semester', m.semester, 'ue_category', m.ue_category, 'academic_year', m.academic_year),
    'lessons', coalesce((
      select jsonb_agg(public._lesson_json(l.id, null) order by l.position, l.id)
      from public.learn_lessons l where l.module_id = m.id and l.status = 'published'), '[]'::jsonb),
    'glossary', coalesce((
      select jsonb_agg(jsonb_build_object('id', g.id, 'fr', g.fr, 'ar', g.ar, 'en', g.en,
                                          'definition', g.definition, 'note', g.note) order by g.id)
      from public.module_glossary g where g.module_id = m.id), '[]'::jsonb),
    'sets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'module_id', s.module_id, 'lesson_id', s.lesson_id, 'ref', s.ref, 'position', s.position,
        'kind', s.kind, 'concept', s.concept, 'difficulty', s.difficulty, 'title', s.title, 'slides', s.slides)
        order by s.position, s.id)
      from public.learn_card_sets s where s.module_id = m.id and not s.hidden and s.status = 'published'), '[]'::jsonb),
    'practice', coalesce((
      select jsonb_agg(jsonb_build_object('chapter_ref', z.chapter_ref, 'unit_number', z.unit_number, 'items', z.items)
                       order by z.unit_number, z.chapter_ref)
      from (select x.chapter_ref, min(x.unit_number) as unit_number,
                   jsonb_agg(public._practice_json(x, null) order by x.position, x.id) as items
              from public.learn_practice x
             where x.module_id = m.id and not x.hidden and x.status = 'published'
             group by x.chapter_ref) z), '[]'::jsonb),
    'exams', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', x.id, 'module_id', x.module_id, 'ref', x.ref, 'position', x.position, 'schema', x.schema,
        'duration_min', x.duration_min, 'total_points', x.total_points,
        'title', x.title, 'instructions', x.instructions, 'exercises', x.exercises) order by x.position, x.id)
      from public.learn_exam_papers x where x.module_id = m.id and not x.hidden and x.status = 'published'), '[]'::jsonb)
  )
  from public.study_modules m where m.id = p_module
$$;
revoke all on function public.cdn_module_export(bigint) from public, anon, authenticated;
grant execute on function public.cdn_module_export(bigint) to service_role;

create or replace function public.cdn_set_path(p_module bigint, p_version integer, p_path text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_now integer;
begin
  if p_path !~ '^v1/m/[0-9]+/[0-9]+-[0-9a-f]{16}/manifest\.json$' then raise exception 'invalid_path'; end if;
  select version into v_now from public.module_content_versions where module_id = p_module for update;
  if v_now is distinct from p_version then raise exception 'version_moved'; end if;
  update public.module_content_versions set cdn_path = p_path, cdn_version = p_version where module_id = p_module;
  return jsonb_build_object('module_id', p_module, 'version', p_version, 'cdn_path', p_path);
end $$;
revoke all on function public.cdn_set_path(bigint, integer, text) from public, anon, authenticated;
grant execute on function public.cdn_set_path(bigint, integer, text) to service_role;

select 'CDN-1 ready' as result,
       has_function_privilege('authenticated', 'public.cdn_module_export(bigint)', 'execute') as students_can_export,
       (select count(*) from public.module_content_versions where cdn_path is not null) as modules_on_cdn;
