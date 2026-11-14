-- =====================================================================
-- 50_BAC1_CATALOG.sql  (BAC_LAUNCH_PLAN Phase 3 / BAC-1). One transaction: all or nothing. Safe to re-run.
-- Bac is a SEPARATE branch: bac streams never appear in the university lists (year_system 'bac'), no
-- university for bac accounts, no school, no birth date. Wilaya only for aggregated wilaya totals.
-- Streams: SE active (offered 3AS); M, MTM, GE, LP, LE "coming soon" (Notify me = join_waitlist).
-- Subjects 3001 SVT, 3002 PHY, 3003 CHEM, 3004 MATH (SE 3AS) show only when they have published content.
-- =====================================================================
begin;

-- profile fields (old apps never send them: all optional)
alter table public.profiles add column if not exists track text not null default 'univ';
alter table public.profiles add column if not exists bac_stream text;
alter table public.profiles add column if not exists bac_year text;
alter table public.profiles add column if not exists wilaya_code smallint;
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_track_chk') then
    alter table public.profiles add constraint profiles_track_chk check (track in ('univ','bac'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_wilaya_chk') then
    alter table public.profiles add constraint profiles_wilaya_chk check (wilaya_code is null or wilaya_code between 1 and 58);
  end if;
end $c$;

-- 58 wilayas (static; the app ships the same list)
create table if not exists public.kl_wilayas (code smallint primary key, name_ar text not null, name_fr text not null);
insert into public.kl_wilayas (code, name_ar, name_fr) values
  (1, 'أدرار', 'Adrar'),
  (2, 'الشلف', 'Chlef'),
  (3, 'الأغواط', 'Laghouat'),
  (4, 'أم البواقي', 'Oum El Bouaghi'),
  (5, 'باتنة', 'Batna'),
  (6, 'بجاية', 'Béjaïa'),
  (7, 'بسكرة', 'Biskra'),
  (8, 'بشار', 'Béchar'),
  (9, 'البليدة', 'Blida'),
  (10, 'البويرة', 'Bouira'),
  (11, 'تمنراست', 'Tamanrasset'),
  (12, 'تبسة', 'Tébessa'),
  (13, 'تلمسان', 'Tlemcen'),
  (14, 'تيارت', 'Tiaret'),
  (15, 'تيزي وزو', 'Tizi Ouzou'),
  (16, 'الجزائر', 'Alger'),
  (17, 'الجلفة', 'Djelfa'),
  (18, 'جيجل', 'Jijel'),
  (19, 'سطيف', 'Sétif'),
  (20, 'سعيدة', 'Saïda'),
  (21, 'سكيكدة', 'Skikda'),
  (22, 'سيدي بلعباس', 'Sidi Bel Abbès'),
  (23, 'عنابة', 'Annaba'),
  (24, 'قالمة', 'Guelma'),
  (25, 'قسنطينة', 'Constantine'),
  (26, 'المدية', 'Médéa'),
  (27, 'مستغانم', 'Mostaganem'),
  (28, 'المسيلة', 'M''Sila'),
  (29, 'معسكر', 'Mascara'),
  (30, 'ورقلة', 'Ouargla'),
  (31, 'وهران', 'Oran'),
  (32, 'البيض', 'El Bayadh'),
  (33, 'إليزي', 'Illizi'),
  (34, 'برج بوعريريج', 'Bordj Bou Arréridj'),
  (35, 'بومرداس', 'Boumerdès'),
  (36, 'الطارف', 'El Tarf'),
  (37, 'تندوف', 'Tindouf'),
  (38, 'تيسمسيلت', 'Tissemsilt'),
  (39, 'الوادي', 'El Oued'),
  (40, 'خنشلة', 'Khenchela'),
  (41, 'سوق أهراس', 'Souk Ahras'),
  (42, 'تيبازة', 'Tipaza'),
  (43, 'ميلة', 'Mila'),
  (44, 'عين الدفلى', 'Aïn Defla'),
  (45, 'النعامة', 'Naâma'),
  (46, 'عين تموشنت', 'Aïn Témouchent'),
  (47, 'غرداية', 'Ghardaïa'),
  (48, 'غليزان', 'Relizane'),
  (49, 'تيميمون', 'Timimoun'),
  (50, 'برج باجي مختار', 'Bordj Badji Mokhtar'),
  (51, 'أولاد جلال', 'Ouled Djellal'),
  (52, 'بني عباس', 'Béni Abbès'),
  (53, 'عين صالح', 'In Salah'),
  (54, 'عين قزام', 'In Guezzam'),
  (55, 'تقرت', 'Touggourt'),
  (56, 'جانت', 'Djanet'),
  (57, 'المغير', 'El M''Ghair'),
  (58, 'المنيعة', 'El Meniaa')
on conflict (code) do update set name_ar = excluded.name_ar, name_fr = excluded.name_fr;
alter table public.kl_wilayas enable row level security;
drop policy if exists kl_wilayas_read on public.kl_wilayas;
create policy kl_wilayas_read on public.kl_wilayas for select to anon, authenticated using (true);
revoke insert, update, delete, truncate on public.kl_wilayas from anon, authenticated;

-- year_system CHECK constraints get the new value 'bac' (existing values kept)
do $ys$
declare r record; v_def text; v_vals text;
begin
  for r in select c.conname, c.conrelid::regclass::text as tbl, pg_get_constraintdef(c.oid) as def
             from pg_constraint c
            where c.contype = 'c' and c.connamespace = 'public'::regnamespace
              and c.conrelid in ('public.specialities'::regclass, 'public.kl_study_levels'::regclass)
              and pg_get_constraintdef(c.oid) ~ 'year_system'
              and pg_get_constraintdef(c.oid) !~ '''bac''' loop
    select string_agg(quote_literal(m[1]), ', ') into v_vals
      from regexp_matches(r.def, '''([^'']+)''', 'g') as m;
    v_vals := coalesce(v_vals || ', ', '') || '''bac''';
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
    execute format('alter table %s add constraint %I check (year_system in (%s))', r.tbl, r.conname, v_vals);
  end loop;
end $ys$;

-- the bac "institution" = a domain, the streams = specialities with year_system 'bac'
insert into public.domains (code, name) select 'bac', 'Baccalauréat'
 where not exists (select 1 from public.domains where code = 'bac');

create table if not exists public.kl_bac_streams (
  code text primary key, speciality_id integer not null unique references public.specialities(id), position smallint not null);
alter table public.kl_bac_streams enable row level security;
revoke all on public.kl_bac_streams from anon, authenticated;

do $s$
declare
  v_dom int := (select id from public.domains where code = 'bac');
  r record; v_id int;
begin
  for r in select * from (values
      ('SE', 1, 'Sciences expérimentales', '{"ar":"علوم تجريبية","fr":"Sciences expérimentales","en":"Experimental sciences"}'),
      ('M',  2, 'Mathématiques',           '{"ar":"رياضيات","fr":"Mathématiques","en":"Mathematics"}'),
      ('MTM',3, 'Techniques mathématiques','{"ar":"تقني رياضي","fr":"Techniques mathématiques","en":"Technical mathematics"}'),
      ('GE', 4, 'Gestion et économie',     '{"ar":"تسيير واقتصاد","fr":"Gestion et économie","en":"Management and economics"}'),
      ('LP', 5, 'Lettres et philosophie',  '{"ar":"آداب وفلسفة","fr":"Lettres et philosophie","en":"Literature and philosophy"}'),
      ('LE', 6, 'Langues étrangères',      '{"ar":"لغات أجنبية","fr":"Langues étrangères","en":"Foreign languages"}')
    ) as t(code, pos, name, i18n) loop
    select speciality_id into v_id from public.kl_bac_streams where code = r.code;
    if v_id is null then
      insert into public.specialities (name, max_year, year_system, domain_id, learn_enabled)
      values ('Bac ' || r.name, 1, 'bac', v_dom, true) returning id into v_id;
      insert into public.kl_bac_streams (code, speciality_id, position) values (r.code, v_id, r.pos);
    end if;
    insert into public.kl_speciality_meta (speciality_id, name_i18n, display_name)
    values (v_id, r.i18n::jsonb, r.name)
    on conflict (speciality_id) do update set name_i18n = excluded.name_i18n, display_name = excluded.display_name, updated_at = now();
  end loop;
end $s$;

-- _levels_for knew only 'lmd' and 'unified' (everything else became lmd): bac streams get the bac levels
create or replace function public._levels_for(p_speciality integer)
 returns setof public.kl_study_levels
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select l.* from public.specialities s
  join public.kl_study_levels l on l.year_system = case when s.year_system in ('unified', 'bac') then s.year_system else 'lmd' end
  where s.id = p_speciality and (s.year_system is distinct from 'unified' or l.position <= coalesce(s.max_year, 6))
  order by l.position
$function$;

-- year 3AS (no semesters)
insert into public.kl_study_levels (year_system, year, position, semesters, label)
select 'bac', '3AS', 1, '{}', '{"ar":"السنة الثالثة ثانوي","fr":"3e année secondaire","en":"3rd year secondary"}'::jsonb
 where not exists (select 1 from public.kl_study_levels where year_system = 'bac' and year = '3AS');

-- only SE 3AS is offered at launch
insert into public.kl_offers (speciality_id, year, enabled)
select b.speciality_id, '3AS', true from public.kl_bac_streams b
 where b.code = 'SE' and not exists (select 1 from public.kl_offers o where o.speciality_id = b.speciality_id and o.year = '3AS');

-- the 4 SE 3AS subjects
do $m$
declare v_se int := (select speciality_id from public.kl_bac_streams where code = 'SE');
        v_dom int := (select id from public.domains where code = 'bac');
        r record;
begin
  for r in select * from (values
      (3001, 'SVT',  'Sciences de la nature et de la vie', '{"ar":"علوم الطبيعة والحياة","fr":"Sciences de la nature et de la vie","en":"Natural and life sciences"}'),
      (3002, 'PHY',  'Physique',                           '{"ar":"الفيزياء","fr":"Physique","en":"Physics"}'),
      (3003, 'CHEM', 'Chimie',                             '{"ar":"الكيمياء","fr":"Chimie","en":"Chemistry"}'),
      (3004, 'MATH', 'Mathématiques',                      '{"ar":"الرياضيات","fr":"Mathématiques","en":"Mathematics"}')
    ) as t(id, code, name, i18n) loop
    insert into public.study_modules (id, domain_id, speciality_id, university_id, academic_year, semester, ue_category, name)
    values (r.id, v_dom, v_se, null, '3AS', null, null, r.name)
    on conflict (id) do nothing;
    insert into public.kl_module_meta (module_id, name_i18n, display_name)
    values (r.id, r.i18n::jsonb, r.name)
    on conflict (module_id) do update set name_i18n = excluded.name_i18n, display_name = excluded.display_name, updated_at = now();
  end loop;
  -- university modules created later must never take ids 3001-3004
  perform setval(pg_get_serial_sequence('public.study_modules', 'id'),
                 greatest((select max(id) from public.study_modules), 3004));
end $m$;

-- onboarding options: bac branch added, bac streams kept out of the university lists
CREATE OR REPLACE FUNCTION public.get_onboarding_options()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'universities', coalesce((select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.name, 'city', u.city, 'wilaya_id', u.wilaya_id) order by u.name)
                                from public.universities u), '[]'::jsonb),
    'specialities', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'name', public._speciality_name(s.id), 'year_system', s.year_system, 'learn_enabled', s.learn_enabled,
        'levels', (select jsonb_agg(jsonb_build_object('year', l.year, 'position', l.position,
                                   'semesters', to_jsonb(l.semesters), 'label', l.label) order by l.position)
                     from public._levels_for(s.id) l
                     where exists (select 1 from public.kl_offers o where o.speciality_id = s.id and o.year = l.year and o.enabled)))
        order by public._speciality_name(s.id))
      from public.specialities s
      where s.year_system <> 'bac'
        and exists (select 1 from public.kl_offers o join public._levels_for(s.id) l on l.year = o.year
                    where o.speciality_id = s.id and o.enabled)), '[]'::jsonb),
    'other_specialities', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'name', public._speciality_name(s.id)) order by public._speciality_name(s.id))
      from public.specialities s
      where s.year_system <> 'bac'
        and not exists (select 1 from public.kl_offers o where o.speciality_id = s.id and o.enabled)), '[]'::jsonb),
    'waitlisted', exists (select 1 from public.kl_waitlist w where w.user_id = auth.uid()),
    -- BAC-1: the bac branch (separate from universities; old apps ignore this key)
    'bac', jsonb_build_object(
      'streams', coalesce((select jsonb_agg(jsonb_build_object(
          'code', b.code, 'id', b.speciality_id, 'position', b.position,
          'name', public._speciality_name(b.speciality_id),
          'name_i18n', coalesce(sm.name_i18n, '{}'::jsonb),
          'active', public._is_offered(b.speciality_id, '3AS')) order by b.position)
        from public.kl_bac_streams b left join public.kl_speciality_meta sm on sm.speciality_id = b.speciality_id), '[]'::jsonb),
      'years', coalesce((select jsonb_agg(jsonb_build_object('year', l.year, 'position', l.position, 'label', l.label) order by l.position)
        from public.kl_study_levels l where l.year_system = 'bac'), '[]'::jsonb)))
$function$;

-- me / catalog: track + bac_stream (wilaya is NOT returned), bac subjects only with content
CREATE OR REPLACE FUNCTION public.get_me()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'id', p.id, 'username', p.username,
    'first_name', coalesce(
        nullif(trim(au.raw_user_meta_data ->> 'given_name'), ''),
        nullif(split_part(trim(coalesce(au.raw_user_meta_data ->> 'full_name', au.raw_user_meta_data ->> 'name', '')), ' ', 1), ''),
        p.username),
    'avatar_url', p.avatar_url, 'avatar_blurhash', p.avatar_blurhash,
    'language', p.preferred_language, 'university_id', p.university_id, 'university_name', u.name,
    'university_city', u.city, 'speciality_id', p.speciality_id, 'speciality_name', public._speciality_name(s.id),
    'academic_year', p.academic_year, 'section', p.section, 'group_name', p.group_name,
    'study_goal_minutes', p.study_goal_minutes, 'onboarding_complete', p.onboarding_complete,
    'onboarding_version', p.onboarding_version, 'is_admin', p.is_admin,
    'xp', coalesce(st.xp, 0),
    'current_streak', case when st.last_active_date >= public.algiers_today() - 1 then st.current_streak else 0 end,
    'longest_streak', coalesce(st.longest_streak, 0),
    'today_seconds', coalesce((select d.active_seconds from public.study_daily d
                               where d.user_id = p.id and d.day = public.algiers_today()), 0),
    'reminders_enabled', coalesce((select not r.unsubscribed from public.user_reminder_state r where r.user_id = p.id), true),
    'current_semester', p.current_semester,
    'pinned_semesters', to_jsonb(p.pinned_semesters),
    'year_question_key', public._year_question_key(),
    'year_confirmed_for', p.year_confirmed_for,
    'year_question_due', false,
    'track', p.track, 'bac_stream', p.bac_stream
  )
  from public.profiles p
  left join auth.users au on au.id = p.id
  left join public.universities u on u.id = p.university_id
  left join public.specialities s on s.id = p.speciality_id
  left join public.study_stats st on st.user_id = p.id
  where p.id = auth.uid()
$function$;

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
$function$;

-- set_bac_profile: the bac onboarding (no school, no birth date; username chosen by the student, generated if empty)
create or replace function public.set_bac_profile(p_stream text, p_year text, p_wilaya smallint, p_language text default 'ar',
                                                   p_username text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_spec int;
  v_name text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select speciality_id into v_spec from public.kl_bac_streams where code = p_stream;
  if v_spec is null then raise exception 'invalid_stream'; end if;
  if not exists (select 1 from public.kl_study_levels where year_system = 'bac' and year = p_year) then raise exception 'invalid_year'; end if;
  if not public._is_offered(v_spec, p_year) then raise exception 'not_offered'; end if;
  if p_wilaya is null or p_wilaya not between 1 and 58 then raise exception 'invalid_wilaya'; end if;
  if p_language is null or p_language not in ('ar','fr','en') then raise exception 'invalid_language'; end if;
  insert into public.profiles (id) values (uid) on conflict (id) do nothing;
  -- founder decision: bac students choose their username (same rule as university); empty = generated
  v_name := lower(trim(coalesce(p_username, '')));
  if v_name <> '' then
    if v_name !~ '^[a-z0-9_.]{3,20}$' then raise exception 'invalid_username'; end if;
    if exists (select 1 from public.profiles x where lower(x.username) = v_name and x.id <> uid) then
      raise exception 'username_taken'; end if;
  else
    select username into v_name from public.profiles where id = uid;
  end if;
  if v_name is null or v_name !~ '^[a-z0-9_.]{3,20}$' then
    loop
      v_name := 'bac_' || lpad((floor(random() * 1000000))::int::text, 6, '0');
      exit when not exists (select 1 from public.profiles where lower(username) = v_name);
    end loop;
  end if;
  update public.profiles
     set track = 'bac', bac_stream = p_stream, bac_year = p_year, wilaya_code = p_wilaya,
         username = v_name, university_id = null, speciality_id = v_spec, academic_year = p_year,
         current_semester = null, pinned_semesters = '{}', preferred_language = p_language,
         onboarding_complete = true, onboarding_version = 1, year_confirmed_for = public._year_question_key()
   where id = uid;
  delete from public.kl_waitlist where user_id = uid;
  insert into public.study_stats (user_id) values (uid) on conflict (user_id) do nothing;
  insert into public.user_reminder_state (user_id, last_active_at) values (uid, now()) on conflict (user_id) do nothing;
  return public.get_me();
end $$;
revoke all on function public.set_bac_profile(text, text, smallint, text, text) from public, anon;
grant execute on function public.set_bac_profile(text, text, smallint, text, text) to authenticated, service_role;

-- university onboarding must never accept a bac stream (and vice versa)
create or replace function public._is_univ_speciality(p_speciality integer) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.specialities s where s.id = p_speciality and s.year_system <> 'bac') $$;
revoke all on function public._is_univ_speciality(integer) from public, anon, authenticated;

-- university flows refuse bac streams
CREATE OR REPLACE FUNCTION public.complete_onboarding(p_username text, p_university_id integer, p_speciality_id integer, p_academic_year text, p_language text DEFAULT 'en'::text, p_section text DEFAULT NULL::text, p_group text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid uuid := auth.uid();
  uname text := lower(trim(coalesce(p_username, '')));
  sems smallint[];
  mon int := extract(month from public.algiers_today())::int;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if uname !~ '^[a-z0-9_.]{3,20}$' then raise exception 'invalid_username'; end if;
  if exists (select 1 from public.profiles x where lower(x.username) = uname and x.id <> uid) then raise exception 'username_taken'; end if;
  if not exists (select 1 from public.universities where id = p_university_id) then raise exception 'invalid_university'; end if;
  if not public._is_univ_speciality(p_speciality_id) then raise exception 'invalid_speciality'; end if;
  if p_language is null or p_language not in ('ar','fr','en') then raise exception 'invalid_language'; end if;
  select l.semesters into sems from public._levels_for(p_speciality_id) l where l.year = p_academic_year;
  if sems is null then raise exception 'invalid_year'; end if;
  if not public._is_offered(p_speciality_id, p_academic_year) then raise exception 'not_offered'; end if;
  insert into public.profiles (id, username) values (uid, uname) on conflict (id) do nothing;
  update public.profiles
     set username = uname, university_id = p_university_id, speciality_id = p_speciality_id,
         academic_year = p_academic_year, preferred_language = p_language,
         section = nullif(left(trim(coalesce(p_section, '')), 20), ''),
         group_name = nullif(left(trim(coalesce(p_group, '')), 20), ''),
         onboarding_complete = true, onboarding_version = 1,
         track = 'univ', bac_stream = null, bac_year = null, wilaya_code = null,
         current_semester = case when cardinality(sems) = 0 then null
                                 when current_semester = any(sems) then current_semester
                                 when mon between 2 and 6 and cardinality(sems) >= 2 then sems[2]
                                 else sems[1] end,
         pinned_semesters = '{}', year_confirmed_for = public._year_question_key()
   where id = uid;
  if not found then raise exception 'profile_missing'; end if;
  delete from public.kl_waitlist where user_id = uid;
  insert into public.study_stats (user_id) values (uid) on conflict (user_id) do nothing;
  insert into public.user_reminder_state (user_id, last_active_at) values (uid, now()) on conflict (user_id) do nothing;
  return public.get_me();
end
$function$;

CREATE OR REPLACE FUNCTION public.set_study_profile(p_speciality integer, p_year text, p_semester smallint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare uid uuid := auth.uid(); sems smallint[];
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.profiles where id = uid) then raise exception 'profile_missing'; end if;
  if not public._is_univ_speciality(p_speciality) then raise exception 'invalid_speciality'; end if;
  select l.semesters into sems from public._levels_for(p_speciality) l where l.year = p_year;
  if sems is null then raise exception 'invalid_year'; end if;
  if not public._is_offered(p_speciality, p_year) then raise exception 'not_offered'; end if;
  if cardinality(sems) = 0 then
    if p_semester is not null then raise exception 'invalid_semester'; end if;
  elsif p_semester is null or not (p_semester = any(sems)) then
    raise exception 'invalid_semester';
  end if;
  update public.profiles set speciality_id = p_speciality, academic_year = p_year, current_semester = p_semester,
         pinned_semesters = '{}', year_confirmed_for = public._year_question_key() where id = uid;
  return public.get_me();
end
$function$;

-- self-check: 3AS must be a level of SE (otherwise everything above rolls back)
do $chk$
declare v_se int := (select speciality_id from public.kl_bac_streams where code = 'SE');
begin
  if not exists (select 1 from public._levels_for(v_se) l where l.year = '3AS') then
    raise exception 'BAC-1: _levels_for does not return 3AS for SE - nothing applied, tell the engineer';
  end if;
  if not public._is_offered(v_se, '3AS') then raise exception 'BAC-1: SE 3AS not offered - nothing applied'; end if;
end $chk$;

commit;

select (select count(*) from public.kl_wilayas) as wilayas,
       (select string_agg(code || '=' || speciality_id, ', ' order by position) from public.kl_bac_streams) as streams,
       (select string_agg(id::text, ', ' order by id) from public.study_modules where academic_year = '3AS') as bac_modules;
