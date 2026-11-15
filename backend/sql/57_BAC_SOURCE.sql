-- =====================================================================
-- 57_BAC_SOURCE.sql  (BAC-UPLOAD, D-05). Safe to re-run. Old apps: nothing changes.
-- Real bac items carry a "source" ({"type":"bac","year":2019,...}); reworded drills carry "based_on" (NEVER a badge).
-- 1) source + based_on (jsonb, null by default) on learn_cards, learn_questions, learn_practice.
-- 2) _lesson_json / _practice_json add the two keys ONLY when set: every existing lesson / practice JSON stays
--    byte-identical (no re-download for anybody, CDN files of module 1005 unchanged).
-- 3) get_module_manifest: lesson rev also covers source/based_on (null adds nothing: existing revs unchanged).
--    Practice rev already hashes _practice_json. cdn_module_export uses the same functions: nothing else to change.
-- Run BEFORE the bac import (the importer v3 checks that the columns exist).
-- =====================================================================
alter table public.learn_cards     add column if not exists source jsonb, add column if not exists based_on jsonb;
alter table public.learn_questions add column if not exists source jsonb, add column if not exists based_on jsonb;
alter table public.learn_practice  add column if not exists source jsonb, add column if not exists based_on jsonb;

CREATE OR REPLACE FUNCTION public._lesson_json(p_lesson bigint, p_langs text[])
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'id', l.id, 'position', l.position, 'source_lang', l.source_lang,
    'unit', jsonb_build_object('ref', l.chapter_ref, 'number', l.unit_number,
                               'title', public._filter_langs(l.unit_title, p_langs)),
    'estimated_minutes', l.estimated_minutes,
    'source_pages', l.source_pages,
    'i18n', coalesce((
      select jsonb_object_agg(li.lang, jsonb_build_object(
        'title', li.title, 'summary', li.summary, 'body_md', li.body_md,
        'key_terms', li.key_terms, 'blocks', li.blocks))
      from public.learn_lesson_i18n li
      where li.lesson_id = l.id and (p_langs is null or li.lang = any(p_langs))), '{}'::jsonb),
    'cards', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'position', c.position, 'concept', c.concept, 'difficulty', c.difficulty, 'card_kind', c.card_kind,
        'figure', public._filter_langs_deep(c.figure, p_langs),
        'i18n', coalesce((
          select jsonb_object_agg(ci.lang, jsonb_build_object('front', ci.front, 'back', ci.back))
          from public.learn_card_i18n ci
          where ci.card_id = c.id and (p_langs is null or ci.lang = any(p_langs))), '{}'::jsonb)
      ) || jsonb_strip_nulls(jsonb_build_object('source', c.source, 'based_on', c.based_on))
      order by c.position, c.id)
      from public.learn_cards c where c.lesson_id = l.id and not c.hidden), '[]'::jsonb),
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', q.id, 'kind', q.kind, 'correct_index', q.correct_index, 'position', q.position,
        'concept', q.concept, 'difficulty', q.difficulty,
        'figure', public._filter_langs_deep(q.figure, p_langs),
        'option_figures', public._filter_langs_deep(q.option_figures, p_langs),
        'i18n', coalesce((
          select jsonb_object_agg(qi.lang, jsonb_build_object(
            'prompt', qi.prompt, 'options', qi.options, 'explanation', qi.explanation))
          from public.learn_question_i18n qi
          where qi.question_id = q.id and (p_langs is null or qi.lang = any(p_langs))), '{}'::jsonb)
      ) || jsonb_strip_nulls(jsonb_build_object('source', q.source, 'based_on', q.based_on))
      order by q.position, q.id)
      from public.learn_questions q where q.lesson_id = l.id and not q.hidden), '[]'::jsonb),
    'resources', coalesce((
      select jsonb_agg(jsonb_build_object('resource_id', lr.resource_id, 'role', lr.role))
      from public.learn_lesson_resources lr where lr.lesson_id = l.id), '[]'::jsonb)
  )
  from public.learn_lessons l where l.id = p_lesson
$function$;

CREATE OR REPLACE FUNCTION public._practice_json(x learn_practice, p_langs text[])
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  select jsonb_build_object(
    'id', x.id, 'ref', x.ref, 'chapter_ref', x.chapter_ref, 'unit_number', x.unit_number, 'position', x.position,
    'difficulty', x.difficulty, 'concepts', to_jsonb(x.concepts),
    'title', public._filter_langs_deep(x.title, p_langs), 'statement', public._filter_langs_deep(x.statement, p_langs),
    'figure', public._filter_langs_deep(x.figure, p_langs), 'table', public._filter_langs_deep(x.table_data, p_langs),
    'parts', public._filter_langs_deep(x.parts, p_langs))
    || jsonb_strip_nulls(jsonb_build_object('source', x.source, 'based_on', x.based_on))
$function$;

CREATE OR REPLACE FUNCTION public.get_module_manifest(p_module bigint, p_langs text[] DEFAULT NULL::text[], p_preview boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare prev boolean := coalesce(p_preview, false) and public.is_admin();
begin
  if not public.user_in_module(p_module) and not prev then raise exception 'not_in_module'; end if;
  if p_langs is not null and exists (select 1 from unnest(p_langs) x where x not in ('ar','fr','en')) then
    raise exception 'invalid_language';
  end if;
  return (
    select jsonb_build_object(
      'schema_version', 3,
      'module', jsonb_build_object('id', m.id, 'name', coalesce((select x.display_name from public.kl_module_meta x where x.module_id = m.id), m.name), 'semester', m.semester,
                                   'ue_category', m.ue_category, 'academic_year', m.academic_year),
      'version', coalesce((select v.version from public.module_content_versions v where v.module_id = m.id), 0),
      'generated_at', now(),
      'lessons', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', l.id, 'position', l.position,
          'unit', jsonb_build_object('ref', l.chapter_ref, 'number', l.unit_number,
                                     'title', public._filter_langs(l.unit_title, p_langs)),
          'estimated_minutes', l.estimated_minutes,
          'titles', coalesce((select jsonb_object_agg(li.lang, li.title) from public.learn_lesson_i18n li
                              where li.lesson_id = l.id and (p_langs is null or li.lang = any(p_langs))), '{}'::jsonb),
          'cards',     (select count(*)::int from public.learn_cards c where c.lesson_id = l.id and not c.hidden),
          'questions', (select count(*)::int from public.learn_questions q where q.lesson_id = l.id and not q.hidden),
          'kb', (select round(sum(length(li.blocks::text)) / 1024.0)::int from public.learn_lesson_i18n li
                 where li.lesson_id = l.id and (p_langs is null or li.lang = any(p_langs))),
          'rev', md5(concat_ws('|',
              l.position, l.chapter_ref, l.unit_number, l.unit_title::text, l.estimated_minutes,
              (select md5(coalesce(string_agg(li.lang || li.title || coalesce(li.summary, '') || li.blocks::text, '' order by li.lang), ''))
                 from public.learn_lesson_i18n li where li.lesson_id = l.id and (p_langs is null or li.lang = any(p_langs))),
              (select md5(coalesce(string_agg(c.id::text || coalesce(c.concept, '') || coalesce(c.difficulty, 0)::text || ci.lang || ci.front || ci.back
                                              || coalesce(c.figure::text, '') || coalesce(c.source::text, '') || coalesce(c.based_on::text, ''), '' order by c.id, ci.lang), ''))
                 from public.learn_cards c join public.learn_card_i18n ci on ci.card_id = c.id
                where c.lesson_id = l.id and not c.hidden and (p_langs is null or ci.lang = any(p_langs))),
              (select md5(coalesce(string_agg(q.id::text || q.correct_index::text || coalesce(q.concept, '') || qi.lang || qi.prompt || qi.options::text || coalesce(qi.explanation, '')
                                              || coalesce(q.figure::text, '') || coalesce(q.option_figures::text, '') || coalesce(q.source::text, '') || coalesce(q.based_on::text, ''), '' order by q.id, qi.lang), ''))
                 from public.learn_questions q join public.learn_question_i18n qi on qi.question_id = q.id
                where q.lesson_id = l.id and not q.hidden and (p_langs is null or qi.lang = any(p_langs))))
          )
        ) order by l.position, l.id)
        from public.learn_lessons l
        where l.module_id = m.id and (l.status = 'published' or prev)), '[]'::jsonb),
      'extras_rev', md5(
        coalesce((select string_agg(g.id::text || coalesce(g.fr, '') || coalesce(g.ar, '') || coalesce(g.en, '') || coalesce(g.definition::text, ''), '' order by g.id)
                    from public.module_glossary g where g.module_id = m.id), '') ||
        coalesce((select string_agg(s.id::text || s.slides::text || s.title::text || s.hidden::text, '' order by s.id)
                    from public.learn_card_sets s where s.module_id = m.id and (s.status = 'published' or prev)), '')),
      'sets', (select count(*)::int from public.learn_card_sets s where s.module_id = m.id and not s.hidden and (s.status = 'published' or prev)),
      'glossary', (select count(*)::int from public.module_glossary g where g.module_id = m.id),
      -- NEW in file 15: one entry per chapter that has practice problems -> get_practice(module, chapter_ref)
      'practice', coalesce((
        select jsonb_agg(jsonb_build_object('chapter_ref', z.chapter_ref, 'unit_number', z.unit_number,
                                            'count', z.n, 'rev', z.rev) order by z.unit_number, z.chapter_ref)
        from (select x.chapter_ref, min(x.unit_number) as unit_number, count(*)::int as n,
                     md5(string_agg(x.id::text || public._practice_json(x, p_langs)::text, '' order by x.position, x.id)) as rev
                from public.learn_practice x
               where x.module_id = m.id and not x.hidden and (x.status = 'published' or prev)
               group by x.chapter_ref) z), '[]'::jsonb),
      -- NEW in file 15: one entry per mock paper -> get_exam_paper(id)
      'exams', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', x.id, 'ref', x.ref, 'position', x.position, 'duration_min', x.duration_min, 'total_points', x.total_points,
          'title', public._filter_langs(x.title, p_langs), 'exercises', jsonb_array_length(x.exercises),
          'kb', round(length(public._filter_langs_deep(x.exercises, p_langs)::text) / 1024.0)::int,
          'rev', md5(concat_ws('|', x.duration_min, x.total_points, public._filter_langs_deep(x.title, p_langs)::text,
                               public._filter_langs_deep(x.instructions, p_langs)::text, public._filter_langs_deep(x.exercises, p_langs)::text))
        ) order by x.position, x.id)
        from public.learn_exam_papers x
        where x.module_id = m.id and not x.hidden and (x.status = 'published' or prev)), '[]'::jsonb)
    )
    from public.study_modules m where m.id = p_module
  );
end $function$;

select 'BAC source ready' as result,
       (select count(*) from information_schema.columns where table_schema = 'public'
          and table_name in ('learn_cards','learn_questions','learn_practice') and column_name in ('source','based_on')) as new_columns_of_6,
       has_function_privilege('anon', 'public.get_module_manifest(bigint,text[],boolean)', 'execute') as anon_can_run_manifest;
