-- KAMPUSLINK FILE 35: achievement posts (students post a REAL achievement to their classmates' stories, one tap, no text,
-- no photos), a bigger shop (frames, titles, more themes), achievements recorded even when the daily coin cap is reached.
-- Run ONCE in the Supabase SQL editor after file 33. Then run file 36 (test, rolls back).
-- Visibility: classmates = same speciality + same year (app_config posts_scope = 'university' adds the same university).
-- Safety: no free text, no pictures, no comments/reactions; blocked users never see each other; 3 reports hide a post;
-- the author can delete it; a post lives 24 h.

-- =============================================================================
-- PART 1  CONFIG, TEMPLATE, SHOP ITEMS
-- =============================================================================
insert into public.app_config (key, value) values
  ('posts_enabled',      'true'::jsonb),
  ('posts_scope',        '"speciality_year"'::jsonb),
  ('posts_per_day',      '5'::jsonb),
  ('post_window_hours',  '48'::jsonb),          -- an achievement can be posted during this time
  ('post_exam_min_20',   '10'::jsonb),          -- mock exams are postable from 10/20
  ('post_reports_hide',  '3'::jsonb),
  ('achievement_streaks','[3,7,14,30,50,100]'::jsonb)
on conflict (key) do nothing;

do $k35$
declare c text;
begin
  select conname into c from pg_constraint
   where conrelid = 'public.kl_story_templates'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%explainer%';
  if c is not null then execute format('alter table public.kl_story_templates drop constraint %I', c); end if;
  alter table public.kl_story_templates add constraint kl_story_templates_type_check
    check (type in ('question','trap','plan','streak','recap','explainer','news','fun','achievement'));
end
$k35$;
insert into public.kl_story_templates (type, name_i18n, cta_i18n, icon, colors, duration_ms, is_interactive, sort) values
  ('achievement','{"en":"Achievement","fr":"Réussite","ar":"إنجاز"}','{"en":"Post to my story","fr":"Publier dans ma story","ar":"انشر في قصتي"}',
   'trophy','{"bg":"#1B7F5A","fg":"#FFFFFF","accent":"#FFD43B"}',6000,false,5)
on conflict (type) do nothing;

insert into public.kl_shop_items (id, kind, price, name_i18n, desc_i18n, payload, sort) values
  ('theme_ocean','theme',400,'{"en":"Ocean","fr":"Océan","ar":"محيط"}','{"en":"Deep sea blue.","fr":"Bleu des profondeurs.","ar":"أزرق البحر العميق."}','{"primary":"#0B7285"}',41),
  ('theme_violet','theme',400,'{"en":"Violet","fr":"Violet","ar":"بنفسجي"}','{"en":"A soft purple look.","fr":"Un look violet doux.","ar":"مظهر بنفسجي ناعم."}','{"primary":"#7048E8"}',42),
  ('theme_rose','theme',400,'{"en":"Rose","fr":"Rose","ar":"وردي"}','{"en":"Bright and warm.","fr":"Vif et chaleureux.","ar":"مشرق ودافئ."}','{"primary":"#D6336C"}',43),
  ('theme_gold','theme',900,'{"en":"Gold","fr":"Or","ar":"ذهبي"}','{"en":"For the hardest workers.","fr":"Pour les plus travailleurs.","ar":"للأكثر اجتهاداً."}','{"primary":"#B8860B"}',44),
  ('frame_fire','frame',600,'{"en":"Fire frame","fr":"Cadre feu","ar":"إطار النار"}','{"en":"A flame ring around your story circle.","fr":"Un anneau de flammes autour de ton cercle.","ar":"حلقة من اللهب حول دائرة قصتك."}','{"colors":["#FF922B","#E03131"]}',50),
  ('frame_ice','frame',600,'{"en":"Ice frame","fr":"Cadre glace","ar":"إطار الجليد"}','{"en":"A cool blue ring.","fr":"Un anneau bleu glacé.","ar":"حلقة زرقاء باردة."}','{"colors":["#74C0FC","#1971C2"]}',51),
  ('frame_forest','frame',600,'{"en":"Forest frame","fr":"Cadre forêt","ar":"إطار الغابة"}','{"en":"A green ring.","fr":"Un anneau vert.","ar":"حلقة خضراء."}','{"colors":["#8CE99A","#2B8A3E"]}',52),
  ('frame_gold','frame',1500,'{"en":"Gold frame","fr":"Cadre or","ar":"إطار ذهبي"}','{"en":"The rarest ring. Classmates will notice.","fr":"L’anneau le plus rare. Tes camarades le verront.","ar":"أندر حلقة. سيلاحظها زملاؤك."}','{"colors":["#FFE066","#B8860B"]}',53),
  ('title_night_owl','title',300,'{"en":"Night owl","fr":"Oiseau de nuit","ar":"بومة الليل"}','{"en":"Shown under your name.","fr":"Affiché sous ton nom.","ar":"يظهر تحت اسمك."}','{}',60),
  ('title_early_bird','title',300,'{"en":"Early bird","fr":"Lève-tôt","ar":"المبكّر"}','{"en":"Shown under your name.","fr":"Affiché sous ton nom.","ar":"يظهر تحت اسمك."}','{}',61),
  ('title_formula_master','title',500,'{"en":"Formula master","fr":"Maître des formules","ar":"سيد المعادلات"}','{"en":"Shown under your name.","fr":"Affiché sous ton nom.","ar":"يظهر تحت اسمك."}','{}',62),
  ('title_future_engineer','title',500,'{"en":"Future engineer","fr":"Futur ingénieur","ar":"مهندس المستقبل"}','{"en":"Shown under your name.","fr":"Affiché sous ton nom.","ar":"يظهر تحت اسمك."}','{}',63),
  ('title_unstoppable','title',1200,'{"en":"Unstoppable","fr":"Inarrêtable","ar":"لا يُوقَف"}','{"en":"Shown under your name.","fr":"Affiché sous ton nom.","ar":"يظهر تحت اسمك."}','{}',64)
on conflict (id) do nothing;

-- =============================================================================
-- PART 2  TABLES
-- =============================================================================
create table if not exists public.kl_achievements (       -- real study events, written by the server only
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       text not null check (kind in ('lesson_done','exam','daily_goal','streak')),
  ref        text not null,
  payload    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, kind, ref)
);
create index if not exists kl_achievements_user_idx on public.kl_achievements (user_id, created_at desc);

create table if not exists public.kl_story_posts (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  achievement_id bigint not null unique references public.kl_achievements(id) on delete cascade,   -- one post per achievement
  kind           text not null,
  payload        jsonb not null default '{}'::jsonb,
  speciality_id  int,
  academic_year  text,
  university_id  int,
  hidden         boolean not null default false,
  created_at     timestamptz not null default now()
);
create index if not exists kl_story_posts_scope_idx on public.kl_story_posts (speciality_id, academic_year, created_at desc) where not hidden;

create table if not exists public.kl_story_post_reports (
  post_id    uuid not null references public.kl_story_posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

do $s35$
declare t text;
begin
  foreach t in array array['kl_achievements','kl_story_posts','kl_story_post_reports'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke insert, update, delete, truncate on public.%I from authenticated', t);
  end loop;
end
$s35$;

-- =============================================================================
-- PART 3  ACHIEVEMENTS (recorded even when no coins are paid) + coin hook v2
-- =============================================================================
create or replace function public._note_achievement(p_uid uuid, p_kind text, p_ref text, p_payload jsonb)
returns void language sql security definer set search_path = public as $f$
  insert into public.kl_achievements (user_id, kind, ref, payload) values (p_uid, p_kind, p_ref, p_payload)
  on conflict (user_id, kind, ref) do nothing
$f$;

create or replace function public._coins_after_op(p_uid uuid, p_op uuid, p_kind text, pl jsonb)
returns int language plpgsql security definer set search_path = public as $f$
declare
  total int := 0; today date := public.algiers_today(); b int; secs int; goal int; pid bigint; sc numeric; lid bigint; mid bigint; st public.study_stats;
begin
  begin
    if p_kind = 'review' then
      if coalesce((pl ->> 'correct')::boolean, false) then
        select p.box into b from public.learn_card_progress p where p.user_id = p_uid and p.card_id = (pl ->> 'card_id')::bigint;
        if coalesce(b, 0) >= 5 then total := total + public._award_coins(p_uid, 'card_mastered', 'card:' || (pl ->> 'card_id')); end if;
        total := total + public._award_coins(p_uid, 'card_got_it', 'op:' || p_op::text);
      end if;
    elsif p_kind = 'lesson_done' then
      lid := (pl ->> 'lesson_id')::bigint;
      total := total + public._award_coins(p_uid, 'lesson_done', 'lesson:' || lid::text);
      select l.module_id into mid from public.learn_lessons l where l.id = lid;
      perform public._note_achievement(p_uid, 'lesson_done', 'lesson:' || lid::text, jsonb_build_object(
        'lesson_id', lid, 'module', public._module_card(mid),
        'lesson_title_i18n', coalesce((select jsonb_object_agg(li.lang, li.title) from public.learn_lesson_i18n li where li.lesson_id = lid), '{}'::jsonb)));
    elsif p_kind = 'study_time' then
      select coalesce(d.active_seconds, 0), coalesce(p.study_goal_minutes, 30) * 60 into secs, goal
        from public.profiles p left join public.study_daily d on d.user_id = p.id and d.day = today where p.id = p_uid;
      if secs >= goal then
        total := total + public._award_coins(p_uid, 'daily_goal', 'day:' || today::text);
        perform public._note_achievement(p_uid, 'daily_goal', 'day:' || today::text, jsonb_build_object('minutes', secs / 60));
      end if;
    elsif p_kind = 'exam_attempt' then
      select a.paper_id, a.score_20 into pid, sc from public.learn_exam_attempts a
       where a.id = (pl ->> 'attempt_id')::uuid and a.user_id = p_uid and a.status = 'finished' and a.total > 0;
      if pid is not null then
        total := total + public._award_coins(p_uid, 'exam_selfscore', 'paper:' || pid::text);
        perform public._note_achievement(p_uid, 'exam', 'attempt:' || (pl ->> 'attempt_id'), (
          select jsonb_build_object('paper_id', pid, 'score_20', sc, 'paper_title', x.title, 'module', public._module_card(x.module_id))
            from public.learn_exam_papers x where x.id = pid));
      end if;
    end if;
    if p_kind not in ('app_open', 'reading_position', 'story_view') then
      total := total + public._streak_milestone(p_uid);
      select * into st from public.study_stats where user_id = p_uid;
      if st.last_active_date = today and exists (
           select 1 from jsonb_array_elements_text(coalesce((select c.value from public.app_config c where c.key = 'achievement_streaks'), '[]'::jsonb)) e
            where e.value ~ '^[0-9]+$' and e.value::int = st.current_streak) then
        perform public._note_achievement(p_uid, 'streak', 'streak:' || st.current_streak || ':' || (today - (st.current_streak - 1))::text,
                                         jsonb_build_object('days', st.current_streak));
      end if;
    end if;
  exception when others then
    raise warning 'coins hook skipped: %', sqlerrm;
    return 0;
  end;
  return total;
end
$f$;

-- =============================================================================
-- PART 4  POSTS
-- =============================================================================
-- who the author is on a story: username + the equipped title and frame (bought in the shop)
create or replace function public._author_card(p_uid uuid)
returns jsonb language sql stable security definer set search_path = public as $f$
  select jsonb_build_object('id', p.id, 'username', p.username,
    'title', (select s.name_i18n from public.kl_user_inventory i join public.kl_shop_items s on s.id = i.item_id
               where i.user_id = p.id and i.equipped and s.kind = 'title' limit 1),
    'frame', (select s.payload -> 'colors' from public.kl_user_inventory i join public.kl_shop_items s on s.id = i.item_id
               where i.user_id = p.id and i.equipped and s.kind = 'frame' limit 1))
    from public.profiles p where p.id = p_uid
$f$;

create or replace function public._postable(p_uid uuid)
returns jsonb language sql stable security definer set search_path = public as $f$
  select coalesce(jsonb_agg(jsonb_build_object('achievement_id', a.id, 'kind', a.kind, 'payload', a.payload, 'created_at', a.created_at)
                            order by a.created_at desc), '[]'::jsonb)
    from public.kl_achievements a
   where a.user_id = p_uid
     and a.created_at > now() - make_interval(hours => public._cfg_int('post_window_hours', 48))
     and not exists (select 1 from public.kl_story_posts p where p.achievement_id = a.id)
     and (a.kind <> 'exam' or coalesce((a.payload ->> 'score_20')::numeric, 0) >= public._cfg_int('post_exam_min_20', 10))
$f$;

create or replace function public.get_my_achievements()
returns jsonb language plpgsql stable security definer set search_path = public as $f$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return public._postable(auth.uid());
end
$f$;

create or replace function public.post_achievement(p_achievement bigint)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare uid uuid := auth.uid(); a public.kl_achievements; pr public.profiles; pid uuid; n int;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if coalesce((select c.value #>> '{}' from public.app_config c where c.key = 'posts_enabled'), 'true') <> 'true' then raise exception 'posts_disabled'; end if;
  select * into a from public.kl_achievements where id = p_achievement and user_id = uid;
  if a.id is null then raise exception 'not_found'; end if;
  if not exists (select 1 from jsonb_array_elements(public._postable(uid)) e where (e ->> 'achievement_id')::bigint = a.id) then
    if exists (select 1 from public.kl_story_posts p where p.achievement_id = a.id) then raise exception 'already_posted'; end if;
    raise exception 'not_postable';
  end if;
  select count(*) into n from public.kl_story_posts p where p.user_id = uid and p.created_at > now() - interval '24 hours';
  if n >= public._cfg_int('posts_per_day', 5) then raise exception 'daily_limit'; end if;
  select * into pr from public.profiles where id = uid;
  insert into public.kl_story_posts (user_id, achievement_id, kind, payload, speciality_id, academic_year, university_id)
  values (uid, a.id, a.kind, a.payload, pr.speciality_id, pr.academic_year, pr.university_id)
  returning id into pid;
  return jsonb_build_object('post_id', pid, 'story_key', 'post:' || pid::text);
end
$f$;

create or replace function public.delete_my_post(p_post uuid)
returns jsonb language plpgsql security definer set search_path = public as $f$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from public.kl_story_posts where id = p_post and user_id = auth.uid();
  if not found then raise exception 'not_found'; end if;
  return jsonb_build_object('deleted', true);
end
$f$;

create or replace function public.report_post(p_post uuid)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare uid uuid := auth.uid(); n int;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.kl_story_posts where id = p_post and user_id <> uid) then raise exception 'not_found'; end if;
  insert into public.kl_story_post_reports (post_id, user_id) values (p_post, uid) on conflict do nothing;
  select count(*) into n from public.kl_story_post_reports where post_id = p_post;
  if n >= public._cfg_int('post_reports_hide', 3) then update public.kl_story_posts set hidden = true where id = p_post; end if;
  return jsonb_build_object('reported', true);
end
$f$;

-- =============================================================================
-- PART 5  get_my_stories v2: + posts (own first, then classmates, grouped by author in the app) + postable list + me
-- =============================================================================
create or replace function public.get_my_stories()
returns jsonb language plpgsql volatile security definer set search_path = public as $f$
declare
  uid uuid := auth.uid(); today date := public.algiers_today(); pr public.profiles; ulang text;
  mod bigint; frontier public.learn_lessons; frontier_open boolean := false; sd public.kl_story_daily; q public.learn_questions;
  skey text; payload jsonb; ans record; stories jsonb := '[]'::jsonb; tpls jsonb; s record; st jsonb;
  due int; secs int := public._cfg_int('story_card_seconds', 20); minutes int; cur int; nm int; nrw int;
  yq bigint; yn int; yc int; minsample int := public._cfg_int('story_min_sample', 30); bal int;
  expire_auto timestamptz := ((today + 1)::timestamp at time zone 'Africa/Algiers');
  by_uni boolean := coalesce((select c.value #>> '{}' from public.app_config c where c.key = 'posts_scope'), '') = 'university';
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into pr from public.profiles where id = uid;
  if pr.id is null then raise exception 'profile_missing'; end if;
  ulang := coalesce(pr.preferred_language, 'en');

  select l.module_id into mod
    from (select rp.lesson_id, rp.updated_at as at from public.learn_reading_position rp where rp.user_id = uid
          union all
          select qa.lesson_id, qa.created_at from public.learn_quiz_attempts qa where qa.user_id = uid) a
    join public.learn_lessons l on l.id = a.lesson_id and l.status = 'published'
   where l.module_id in (select t.id from public.my_module_ids() as t(id))
   order by a.at desc limit 1;
  if mod is null then
    select t.id into mod from public.my_module_ids() as t(id)
     where exists (select 1 from public.learn_lessons l where l.module_id = t.id and l.status = 'published') order by t.id limit 1;
  end if;

  if mod is not null then
    select * into frontier from public.learn_lessons l
     where l.module_id = mod and l.status = 'published'
       and not exists (select 1 from public.learn_lesson_progress p where p.user_id = uid and p.lesson_id = l.id)
     order by l.position, l.id limit 1;
    frontier_open := frontier.id is not null;
    if not frontier_open then
      select * into frontier from public.learn_lessons l where l.module_id = mod and l.status = 'published' order by l.position desc, l.id desc limit 1;
    end if;

    skey := 'qotd:' || today::text;
    select * into sd from public.kl_story_daily d where d.user_id = uid and d.story_key = skey;
    if sd.user_id is null and frontier.id is not null then
      select qq.* into q from public.learn_questions qq join public.learn_lessons l on l.id = qq.lesson_id
       where l.module_id = mod and l.status = 'published' and not qq.hidden and qq.correct_index is not null
         and (l.position, l.id) <= (frontier.position, frontier.id)
         and exists (select 1 from public.learn_question_i18n i where i.question_id = qq.id
                        and case when jsonb_typeof(to_jsonb(i.options)) = 'array' then jsonb_array_length(to_jsonb(i.options)) between 2 and 4 else false end)
       order by (l.id = frontier.id) desc, md5(uid::text || today::text || qq.id::text) limit 1;
      if q.id is not null then
        insert into public.kl_story_daily (user_id, story_key, day, module_id, question_id, lesson_id)
        values (uid, skey, today, mod, q.id, q.lesson_id) on conflict do nothing;
        select * into sd from public.kl_story_daily d where d.user_id = uid and d.story_key = skey;
      end if;
    end if;
    if sd.user_id is not null and sd.question_id is not null then
      select * into q from public.learn_questions where id = sd.question_id;
      payload := jsonb_build_object('story_key', skey, 'question_id', q.id, 'lesson_id', q.lesson_id, 'module', public._module_card(sd.module_id),
        'correct_index', q.correct_index, 'figure', q.figure, 'option_figures', q.option_figures,
        'i18n', coalesce((select jsonb_object_agg(qi.lang, jsonb_build_object('prompt', qi.prompt, 'options', qi.options, 'explanation', qi.explanation))
                            from public.learn_question_i18n qi where qi.question_id = q.id and qi.lang in (ulang, 'fr', 'en')), '{}'::jsonb));
      select d.question_id into yq from public.kl_story_daily d where d.user_id = uid and d.story_key = 'qotd:' || (today - 1)::text;
      if yq is not null then
        select count(*)::int, count(*) filter (where a.is_correct)::int into yn, yc from public.kl_story_answers a
         where a.question_id = yq and a.day = today - 1 and a.story_key like 'qotd:%';
        if yn >= minsample then
          payload := payload || jsonb_build_object('yesterday', jsonb_build_object('question_id', yq, 'answers', yn, 'pct_correct', round(100.0 * yc / yn)));
        end if;
      end if;
      select a.choice, a.is_correct into ans from public.kl_story_answers a where a.user_id = uid and a.story_key = skey;
      stories := stories || jsonb_build_object('key', skey, 'source', 'auto', 'template', 'question', 'payload', payload, 'expires_at', expire_auto,
        'seen', exists (select 1 from public.kl_story_views v where v.user_id = uid and v.story_key = skey),
        'answered', case when found then jsonb_build_object('choice', ans.choice, 'is_correct', ans.is_correct) end);
    end if;

    select count(*)::int into due from public.learn_card_progress p
      join public.learn_cards c on c.id = p.card_id join public.learn_lessons l on l.id = c.lesson_id
     where p.user_id = uid and p.due_at <= now() and l.status = 'published'
       and l.module_id in (select t.id from public.my_module_ids() as t(id));
    minutes := coalesce(case when frontier_open then frontier.estimated_minutes end, 0) + ceil(due * secs / 60.0)::int;
    if due > 0 or frontier_open then
      skey := 'plan:' || today::text;
      payload := jsonb_build_object('story_key', skey, 'module', public._module_card(mod), 'due_cards', due,
        'lesson_id', case when frontier_open then frontier.id end,
        'lesson_title_i18n', case when frontier_open then coalesce((select jsonb_object_agg(li.lang, li.title) from public.learn_lesson_i18n li
                                    where li.lesson_id = frontier.id and li.lang in (ulang, 'fr', 'en')), '{}'::jsonb) end,
        'lesson_minutes', case when frontier_open then frontier.estimated_minutes end, 'est_minutes', minutes);
      stories := stories || jsonb_build_object('key', skey, 'source', 'auto', 'template', 'plan', 'payload', payload, 'expires_at', expire_auto,
        'seen', exists (select 1 from public.kl_story_views v where v.user_id = uid and v.story_key = skey), 'answered', null);
    end if;
  end if;

  st := public._streak_state(uid); cur := (st ->> 'current')::int;
  if cur >= 1 then
    select m.n, m.amt into nm, nrw from (select case when k.reason ~ '^streak_[0-9]+$' then substring(k.reason from 8)::int end as n, k.amount as amt
                                           from public.kl_coin_rules k where k.active) m
     where m.n > cur order by m.n limit 1;
    skey := 'streak:' || today::text;
    payload := jsonb_build_object('story_key', skey, 'current', cur, 'best', (st ->> 'best')::int, 'freezes', (st -> 'freezes'),
      'protected', (st -> 'protected'), 'studied_today', (st -> 'studied_today'),
      'next_milestone', nm, 'days_to_next', case when nm is not null then nm - cur end, 'next_reward', nrw);
    stories := stories || jsonb_build_object('key', skey, 'source', 'auto', 'template', 'streak', 'payload', payload, 'expires_at', expire_auto,
      'seen', exists (select 1 from public.kl_story_views v where v.user_id = uid and v.story_key = skey), 'answered', null);
  end if;

  -- POSTS: my own first, then classmates (same speciality + year), newest first; blocked people never appear
  for s in
    select p.* from public.kl_story_posts p
     where not p.hidden and p.created_at > now() - interval '24 hours'
       and (p.user_id = uid or (p.speciality_id = pr.speciality_id and p.academic_year = pr.academic_year
                                and (not by_uni or p.university_id = pr.university_id)))
       and not exists (select 1 from public.blocked_users b
                        where (b.blocker_id = uid and b.blocked_id = p.user_id) or (b.blocker_id = p.user_id and b.blocked_id = uid))
     order by (p.user_id = uid) desc, p.created_at desc limit 60
  loop
    skey := 'post:' || s.id::text;
    stories := stories || jsonb_build_object('key', skey, 'source', case when s.user_id = uid then 'mine' else 'post' end,
      'template', 'achievement',
      'payload', s.payload || jsonb_build_object('story_key', skey, 'kind', s.kind, 'post_id', s.id, 'author', public._author_card(s.user_id)),
      'expires_at', s.created_at + interval '24 hours',
      'seen', s.user_id = uid or exists (select 1 from public.kl_story_views v where v.user_id = uid and v.story_key = skey),
      'answered', null);
  end loop;

  for s in
    select x.* from public.kl_stories x
     where x.active and x.publish_at <= now()
       and now() < least(coalesce(x.expires_at, x.publish_at + interval '24 hours'), x.publish_at + interval '24 hours')
       and (x.module_id is null or x.module_id in (select t.id from public.my_module_ids() as t(id)))
       and (x.speciality_id is null or x.speciality_id = pr.speciality_id)
       and (x.academic_year is null or x.academic_year = pr.academic_year)
     order by x.publish_at desc limit 10
  loop
    skey := 'ed:' || s.id::text;
    select a.choice, a.is_correct into ans from public.kl_story_answers a where a.user_id = uid and a.story_key = skey;
    stories := stories || jsonb_build_object('key', skey, 'source', 'editorial', 'template', s.template, 'payload', s.payload || jsonb_build_object('story_key', skey),
      'expires_at', least(coalesce(s.expires_at, s.publish_at + interval '24 hours'), s.publish_at + interval '24 hours'),
      'seen', exists (select 1 from public.kl_story_views v where v.user_id = uid and v.story_key = skey),
      'answered', case when found then jsonb_build_object('choice', ans.choice, 'is_correct', ans.is_correct) end);
  end loop;

  select coalesce(jsonb_object_agg(t.type, jsonb_build_object('name', t.name_i18n, 'cta', t.cta_i18n, 'icon', t.icon, 'colors', t.colors,
           'duration_ms', t.duration_ms, 'interactive', t.is_interactive)), '{}'::jsonb) into tpls from public.kl_story_templates t where t.active;
  select coalesce(sum(l.amount), 0) into bal from public.kl_coin_ledger l where l.user_id = uid;
  return jsonb_build_object('day', today, 'generated_at', now(), 'language', ulang, 'balance', bal, 'templates', tpls, 'stories', stories,
    'me', public._author_card(uid),
    'postable', case when coalesce((select c.value #>> '{}' from public.app_config c where c.key = 'posts_enabled'), 'true') = 'true'
                     then public._postable(uid) else '[]'::jsonb end);
end
$f$;

-- =============================================================================
-- PART 6  PERMISSIONS
-- =============================================================================
do $g35$
declare f text;
begin
  foreach f in array array['public._note_achievement(uuid,text,text,jsonb)','public._coins_after_op(uuid,uuid,text,jsonb)',
      'public._author_card(uuid)','public._postable(uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['public.get_my_achievements()','public.post_achievement(bigint)','public.delete_my_post(uuid)',
      'public.report_post(uuid)','public.get_my_stories()'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$g35$;
notify pgrst, 'reload schema';
