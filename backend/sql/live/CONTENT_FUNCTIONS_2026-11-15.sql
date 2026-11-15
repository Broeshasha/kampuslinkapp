-- READ-ONLY COPY of the live content functions (pg_get_functiondef, 15 Nov 2026). Reference only: do NOT run.
-- The phone's CDN language filter (lib/data/content/lang_filter.dart) mirrors these.

-- ### _filter_langs_deep(j jsonb, p_langs text[])
CREATE OR REPLACE FUNCTION public._filter_langs_deep(j jsonb, p_langs text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
declare t text := jsonb_typeof(j);
begin
  if j is null or p_langs is null then return j; end if;
  if t = 'object' then
    if (select count(*) from jsonb_object_keys(j)) between 2 and 3
       and not exists (select 1 from jsonb_object_keys(j) k where k not in ('en','fr','ar')) then
      return coalesce((select jsonb_object_agg(e.key, e.value) from jsonb_each(j) e where e.key = any(p_langs)), '{}'::jsonb);
    end if;
    return coalesce((select jsonb_object_agg(e.key, public._filter_langs_deep(e.value, p_langs)) from jsonb_each(j) e), '{}'::jsonb);
  elsif t = 'array' then
    return coalesce((select jsonb_agg(public._filter_langs_deep(e.value, p_langs) order by e.n)
                       from jsonb_array_elements(j) with ordinality as e(value, n)), '[]'::jsonb);
  end if;
  return j;
end $function$


-- ### _lesson_json(p_lesson bigint, p_langs text[])
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
      ) order by c.position, c.id)
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
      ) order by q.position, q.id)
      from public.learn_questions q where q.lesson_id = l.id and not q.hidden), '[]'::jsonb),
    'resources', coalesce((
      select jsonb_agg(jsonb_build_object('resource_id', lr.resource_id, 'role', lr.role))
      from public.learn_lesson_resources lr where lr.lesson_id = l.id), '[]'::jsonb)
  )
  from public.learn_lessons l where l.id = p_lesson
$function$


-- ### _practice_json(x learn_practice, p_langs text[])
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
$function$


-- ### get_exam_paper(p_paper bigint, p_langs text[], p_preview boolean)
CREATE OR REPLACE FUNCTION public.get_exam_paper(p_paper bigint, p_langs text[] DEFAULT NULL::text[], p_preview boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare x public.learn_exam_papers; prev boolean := coalesce(p_preview, false) and public.is_admin();
begin
  select * into x from public.learn_exam_papers where id = p_paper;
  if x.id is null or x.hidden then raise exception 'exam_not_found'; end if;
  if not public.user_in_module(x.module_id) and not prev then raise exception 'not_in_module'; end if;
  if x.status <> 'published' and not prev then raise exception 'exam_not_found'; end if;
  if p_langs is not null and exists (select 1 from unnest(p_langs) l where l not in ('ar','fr','en')) then
    raise exception 'invalid_language';
  end if;
  return jsonb_build_object(
    'id', x.id, 'module_id', x.module_id, 'ref', x.ref, 'position', x.position, 'schema', x.schema,
    'duration_min', x.duration_min, 'total_points', x.total_points,
    'title', public._filter_langs_deep(x.title, p_langs),
    'instructions', public._filter_langs_deep(x.instructions, p_langs),
    'exercises', public._filter_langs_deep(x.exercises, p_langs));
end $function$


-- ### get_lesson_bundle(p_lesson bigint, p_langs text[], p_preview boolean)
CREATE OR REPLACE FUNCTION public.get_lesson_bundle(p_lesson bigint, p_langs text[] DEFAULT NULL::text[], p_preview boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare mid bigint; st text; prev boolean := coalesce(p_preview, false) and public.is_admin();
begin
  select l.module_id, l.status into mid, st from public.learn_lessons l where l.id = p_lesson;
  if mid is null then raise exception 'lesson_not_found'; end if;
  if not public.user_in_module(mid) and not prev then raise exception 'not_in_module'; end if;
  if st <> 'published' and not prev then raise exception 'lesson_not_found'; end if;
  if p_langs is not null and exists (select 1 from unnest(p_langs) x where x not in ('ar','fr','en')) then
    raise exception 'invalid_language';
  end if;
  return public._lesson_json(p_lesson, p_langs);
end $function$


-- ### get_module_extras(p_module bigint, p_langs text[], p_preview boolean)
CREATE OR REPLACE FUNCTION public.get_module_extras(p_module bigint, p_langs text[] DEFAULT NULL::text[], p_preview boolean DEFAULT false)
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
  return jsonb_build_object(
    'glossary', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', g.id,
        'fr', case when p_langs is null or 'fr' = any(p_langs) then g.fr end,
        'ar', case when p_langs is null or 'ar' = any(p_langs) then g.ar end,
        'en', case when p_langs is null or 'en' = any(p_langs) then g.en end,
        'definition', public._filter_langs(g.definition, p_langs),
        'note', g.note) order by g.id)
      from public.module_glossary g where g.module_id = p_module), '[]'::jsonb),
    'sets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'module_id', s.module_id, 'lesson_id', s.lesson_id, 'ref', s.ref, 'position', s.position,
        'kind', s.kind, 'concept', s.concept, 'difficulty', s.difficulty, 'title', s.title, 'slides', s.slides)
        order by s.position, s.id)
      from public.learn_card_sets s
      where s.module_id = p_module and not s.hidden and (s.status = 'published' or prev)), '[]'::jsonb),
    'resources', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'type', r.resource_type, 'format', r.file_format, 'title', r.title,
        'file_urls', r.file_urls, 'trust_label', r.trust_label, 'size_bytes', r.size_bytes,
        'origin', r.origin, 'created_at', r.created_at) order by r.created_at desc)
      from public.study_resources r where r.module_id = p_module and r.status = 'visible'), '[]'::jsonb)
  );
end $function$


-- ### get_module_manifest(p_module bigint, p_langs text[], p_preview boolean)
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
                                              || coalesce(c.figure::text, ''), '' order by c.id, ci.lang), ''))
                 from public.learn_cards c join public.learn_card_i18n ci on ci.card_id = c.id
                where c.lesson_id = l.id and not c.hidden and (p_langs is null or ci.lang = any(p_langs))),
              (select md5(coalesce(string_agg(q.id::text || q.correct_index::text || coalesce(q.concept, '') || qi.lang || qi.prompt || qi.options::text || coalesce(qi.explanation, '')
                                              || coalesce(q.figure::text, '') || coalesce(q.option_figures::text, ''), '' order by q.id, qi.lang), ''))
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
end $function$


-- ### get_my_catalog()
CREATE OR REPLACE FUNCTION public.get_my_catalog()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare uid uuid := auth.uid(); p public.profiles;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into p from public.profiles where id = uid;
  if not found then raise exception 'profile_missing'; end if;
  return jsonb_build_object(
    'schema', 1, 'generated_at', now(),
    'config', coalesce((select jsonb_object_agg(c.key, c.value) from public.app_config c), '{}'::jsonb),
    'me', jsonb_build_object('track', p.track, 'bac_stream', p.bac_stream, 'academic_year', p.academic_year, 'current_semester', p.current_semester,
                             'speciality_id', p.speciality_id, 'university_id', p.university_id, 'is_admin', p.is_admin),
    'speciality', (select jsonb_build_object('id', s.id, 'name', public._speciality_name(s.id), 'name_i18n', coalesce(sm.name_i18n, '{}'::jsonb),
                                             'year_system', s.year_system, 'learn_enabled', coalesce(s.learn_enabled, false))
                     from public.specialities s left join public.kl_speciality_meta sm on sm.speciality_id = s.id where s.id = p.speciality_id),
    'levels', coalesce((select jsonb_agg(jsonb_build_object('year', l.year, 'position', l.position,
                               'semesters', to_jsonb(l.semesters), 'label', l.label) order by l.position)
                          from public._levels_for(p.speciality_id) l), '[]'::jsonb),
    'modules', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id, 'name', coalesce(mm.display_name, m.name), 'name_i18n', coalesce(mm.name_i18n, '{}'::jsonb), 'icon', mm.icon, 'color', mm.color,
        'semester', m.semester, 'ue_category', m.ue_category, 'academic_year', m.academic_year, 'version', coalesce(v.version, 0),
        'counts', jsonb_build_object(
          'lessons', (select count(*)::int from public.learn_lessons l where l.module_id = m.id and l.status = 'published'),
          'lessons_done', (select count(*)::int from public.learn_lesson_progress lp join public.learn_lessons l on l.id = lp.lesson_id
                            where lp.user_id = uid and l.module_id = m.id and l.status = 'published'),
          'sets', (select count(*)::int from public.learn_card_sets s where s.module_id = m.id and s.status = 'published' and not s.hidden),
          'practice', (select count(*)::int from public.learn_practice x where x.module_id = m.id and x.status = 'published' and not x.hidden),
          'exams', (select count(*)::int from public.learn_exam_papers x where x.module_id = m.id and x.status = 'published' and not x.hidden),
          'resources', (select count(*)::int from public.study_resources r where r.module_id = m.id and r.status = 'visible'))
      ) order by m.semester nulls first, coalesce(mm.name_i18n ->> 'fr', m.name))
      from public.study_modules m
      left join public.kl_module_meta mm on mm.module_id = m.id
      left join public.module_content_versions v on v.module_id = m.id
      where m.id in (select public.my_module_ids())
        -- BAC-1: a bac subject appears only once it has published content
        and (p.track is distinct from 'bac'
             or exists (select 1 from public.learn_lessons l where l.module_id = m.id and l.status = 'published'))), '[]'::jsonb));
end
$function$


-- ### get_my_modules()
CREATE OR REPLACE FUNCTION public.get_my_modules()
 RETURNS TABLE(module_id bigint, name text, semester smallint, ue_category text, academic_year text, version integer, lessons integer, lessons_done integer, resources integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select m.id, m.name, m.semester, m.ue_category, m.academic_year,
         coalesce(v.version, 0),
         (select count(*)::int from public.learn_lessons l
           where l.module_id = m.id and l.status = 'published'),
         (select count(*)::int from public.learn_lesson_progress lp
            join public.learn_lessons l on l.id = lp.lesson_id
           where lp.user_id = auth.uid() and l.module_id = m.id and l.status = 'published'),
         (select count(*)::int from public.study_resources r
           where r.module_id = m.id and r.status = 'visible')
  from public.study_modules m
  left join public.module_content_versions v on v.module_id = m.id
  where m.id in (select public.my_module_ids())
  order by m.semester nulls last, m.name
$function$


-- ### get_practice(p_module bigint, p_chapter text, p_langs text[], p_preview boolean)
CREATE OR REPLACE FUNCTION public.get_practice(p_module bigint, p_chapter text DEFAULT NULL::text, p_langs text[] DEFAULT NULL::text[], p_preview boolean DEFAULT false)
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
  return coalesce((
    select jsonb_agg(public._practice_json(x, p_langs) order by x.position, x.id)
    from public.learn_practice x
    where x.module_id = p_module and not x.hidden and (x.status = 'published' or prev)
      and (p_chapter is null or x.chapter_ref = p_chapter)), '[]'::jsonb);
end $function$


-- ### my_module_ids()
CREATE OR REPLACE FUNCTION public.my_module_ids()
 RETURNS SETOF bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select m.id
  from public.profiles p
  join public.specialities s on s.id = p.speciality_id
  join public.study_modules m
    on m.academic_year = p.academic_year
   and (m.speciality_id = p.speciality_id
        or (m.speciality_id is null and m.domain_id = s.domain_id)
        or exists (select 1 from public.kl_module_links ml where ml.module_id = m.id and ml.speciality_id = p.speciality_id))
   and (m.university_id is null or m.university_id = p.university_id)
  where p.id = auth.uid()
    and not exists (select 1 from public.kl_module_hidden h where h.module_id = m.id)
$function$


-- ### user_in_module(p_module bigint)
CREATE OR REPLACE FUNCTION public.user_in_module(p_module bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from public.my_module_ids() as t(id) where t.id = p_module)
$function$


-- ### zz_columns
app_config.key text nullable=NO default=-
app_config.value jsonb nullable=NO default=-
app_config.updated_at timestamp with time zone nullable=NO default=now()
module_content_versions.module_id bigint nullable=NO default=-
module_content_versions.version integer nullable=NO default=1
module_content_versions.updated_at timestamp with time zone nullable=NO default=now()
module_content_versions.cdn_path text nullable=YES default=-
module_content_versions.cdn_version integer nullable=YES default=-
