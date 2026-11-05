-- KAMPUSLINK FILE 33: coins + shop + stories (backend of Phase 1). KampusLink tables only, nothing of Kampus Store is touched.
-- Run ONCE in the Supabase SQL editor (one transaction: an error rolls everything back). Then run file 34 (test, rolls back).
-- Rules: the SERVER decides every coin (inside sync_progress); ledger is append-only; amounts/caps/prices are ROWS (kl_coin_rules,
--        kl_shop_items, app_config), never an app release; no real numbers are invented (stats only above a minimum sample).
-- Deviation from the brief (on purpose): the streak itself stays in study_stats (one counter, no duplicate);
--        kl_user_streak only holds streak FREEZES.  "confirmed mistake report" coins: rule row exists but is OFF (no confirm event yet).

-- =============================================================================
-- PART 1  CONFIG + COIN TABLES
-- =============================================================================
insert into public.app_config (key, value) values
  ('coins_daily_cap',      '100'::jsonb),   -- max STUDY coins per student per Algiers day (rules with in_global_cap)
  ('coins_max_freezes',    '2'::jsonb),     -- max streak freezes a student can hold
  ('freeze_max_gap_days',  '3'::jsonb),     -- a freeze set covers at most this many missed days in a row (1 freeze = 1 day)
  ('story_min_sample',     '30'::jsonb),    -- "X% got it right" is shown only above this many real answers
  ('story_card_seconds',   '20'::jsonb),    -- planning ESTIMATE: seconds per due card (Your plan story)
  ('invites_enabled',      'false'::jsonb), -- Phase 3 switch
  ('invite_required_days', '3'::jsonb)
on conflict (key) do nothing;

create or replace function public._cfg_int(p_key text, p_default int)
returns int language sql stable security definer set search_path = public as $f$
  select coalesce((select (c.value #>> '{}')::int from public.app_config c where c.key = p_key), p_default)
$f$;

create table if not exists public.kl_coin_rules (
  reason        text primary key,
  amount        int  not null check (amount >= 0),
  daily_cap     int  check (daily_cap is null or daily_cap > 0),   -- max coins of THIS reason per day (null = none)
  in_global_cap boolean not null default true,                      -- counts toward app_config coins_daily_cap
  active        boolean not null default true,
  note          text,
  updated_at    timestamptz not null default now()
);
insert into public.kl_coin_rules (reason, amount, daily_cap, in_global_cap, active, note) values
  ('daily_goal',           15, null, true,  true,  'study goal of the day reached'),
  ('card_mastered',         3, 30,   true,  true,  'a card reaches the top Leitner box (once per card)'),
  ('lesson_done',          10, 30,   true,  true,  'episode finished (once per lesson)'),
  ('exam_selfscore',       20, null, true,  true,  'mock exam finished and self-scored (once per paper)'),
  ('story_question_right', 10, 30,   true,  true,  'story question answered right'),
  ('streak_3',             20, null, false, true,  'streak milestone'),
  ('streak_7',             50, null, false, true,  'streak milestone'),
  ('streak_30',           200, null, false, true,  'streak milestone'),
  ('streak_100',          500, null, false, true,  'streak milestone'),
  ('card_got_it',           2, 20,   true,  false, 'Phase 2 feed "Got it" (off until the feed ships)'),
  ('report_confirmed',     10, null, false, false, 'confirmed mistake report (off: no confirm event yet)'),
  ('invite_inviter',       50, null, false, false, 'Phase 3: friend studied 3 days'),
  ('invite_invitee',       50, null, false, false, 'Phase 3: friend studied 3 days')
on conflict (reason) do nothing;

create table if not exists public.kl_coin_ledger (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  amount     int  not null check (amount <> 0),
  reason     text not null,
  ref        text not null,
  day        date not null default public.algiers_today(),
  created_at timestamptz not null default now(),
  unique (user_id, reason, ref)                    -- idempotent: the same event never pays twice
);
create index if not exists kl_coin_ledger_user_day_idx on public.kl_coin_ledger (user_id, day);

-- append-only: no update ever; delete only when the account itself is gone (cascade of delete_my_account)
create or replace function public._ledger_guard() returns trigger language plpgsql as $f$
begin
  if tg_op = 'UPDATE' then raise exception 'ledger_is_append_only'; end if;
  if tg_op = 'DELETE' and exists (select 1 from public.profiles p where p.id = old.user_id) then
    raise exception 'ledger_is_append_only';
  end if;
  return old;
end
$f$;
drop trigger if exists trg_ledger_guard on public.kl_coin_ledger;
create trigger trg_ledger_guard before update or delete on public.kl_coin_ledger
  for each row execute function public._ledger_guard();

create table if not exists public.kl_shop_items (
  id         text primary key,
  kind       text not null check (kind in ('streak_freeze','theme','card_skin','frame','title','pack')),
  price      int  not null check (price >= 0),
  name_i18n  jsonb not null default '{}'::jsonb,
  desc_i18n  jsonb not null default '{}'::jsonb,
  payload    jsonb not null default '{}'::jsonb,   -- e.g. theme colours; the app maps unknown keys to defaults
  sort       int  not null default 100,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.kl_shop_items (id, kind, price, name_i18n, desc_i18n, payload, sort) values
  ('streak_freeze', 'streak_freeze', 150,
   '{"en":"Streak freeze","fr":"Gel de série","ar":"تجميد السلسلة"}',
   '{"en":"Protects your streak if you miss one day.","fr":"Protège ta série si tu rates un jour.","ar":"يحمي سلسلتك إذا فوّتَّ يوماً واحداً."}',
   '{}', 10),
  ('theme_night', 'theme', 400,
   '{"en":"Night blue","fr":"Bleu nuit","ar":"أزرق ليلي"}',
   '{"en":"A calm dark-blue look.","fr":"Un look bleu nuit apaisant.","ar":"مظهر أزرق داكن هادئ."}',
   '{"primary":"#3B5BDB","surface":"#0B1330"}', 20),
  ('theme_forest', 'theme', 400,
   '{"en":"Forest","fr":"Forêt","ar":"غابة"}',
   '{"en":"Soft greens, easy on the eyes.","fr":"Des verts doux, reposants.","ar":"ألوان خضراء ناعمة مريحة للعين."}',
   '{"primary":"#2F9E44","surface":"#0F2418"}', 30),
  ('theme_sunset', 'theme', 400,
   '{"en":"Sunset","fr":"Coucher de soleil","ar":"غروب"}',
   '{"en":"Warm orange and rose.","fr":"Orange chaud et rose.","ar":"برتقالي دافئ ووردي."}',
   '{"primary":"#E8590C","surface":"#2B1410"}', 40)
on conflict (id) do nothing;

create table if not exists public.kl_user_inventory (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  item_id     text not null references public.kl_shop_items(id),
  acquired_at timestamptz not null default now(),
  equipped    boolean not null default false,
  primary key (user_id, item_id)
);

create table if not exists public.kl_user_streak (          -- only the freezes; the streak counter is study_stats
  user_id          uuid primary key references public.profiles(id) on delete cascade,
  freezes          int  not null default 0 check (freezes >= 0),
  last_freeze_on   date,
  last_freeze_days int,
  updated_at       timestamptz not null default now()
);

-- Phase 3 (switched off): invite codes + invites, rewards come from kl_coin_rules invite_* rows
create table if not exists public.kl_invite_codes (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  code    text not null unique,
  created_at timestamptz not null default now()
);
create table if not exists public.kl_invites (
  id           uuid primary key default gen_random_uuid(),
  inviter_id   uuid not null references public.profiles(id) on delete cascade,
  invitee_id   uuid not null unique references public.profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),
  qualified_at timestamptz,
  rewarded_at  timestamptz,
  check (inviter_id <> invitee_id)
);

-- =============================================================================
-- PART 2  STORIES TABLES
-- =============================================================================
create table if not exists public.kl_story_templates (
  type        text primary key check (type in ('question','trap','plan','streak','recap','explainer','news','fun')),
  name_i18n   jsonb not null default '{}'::jsonb,     -- header text
  cta_i18n    jsonb not null default '{}'::jsonb,     -- button text
  icon        text,
  colors      jsonb not null default '{}'::jsonb,     -- {bg, fg, accent}
  duration_ms int  not null default 7000 check (duration_ms between 2000 and 30000),
  is_interactive boolean not null default false,       -- interactive = the timer stops until answered
  active      boolean not null default true,
  sort        int not null default 100
);
insert into public.kl_story_templates (type, name_i18n, cta_i18n, icon, colors, duration_ms, is_interactive, sort) values
  ('question','{"en":"Question of the day","fr":"Question du jour","ar":"سؤال اليوم"}','{"en":"See the lesson","fr":"Voir la leçon","ar":"شاهد الدرس"}','help','{"bg":"#3B3FD9","fg":"#FFFFFF","accent":"#FFD43B"}',8000,true,10),
  ('plan','{"en":"Your plan today","fr":"Ton plan du jour","ar":"خطتك اليوم"}','{"en":"Start","fr":"Commencer","ar":"ابدأ"}','checklist','{"bg":"#0F8B8D","fg":"#FFFFFF","accent":"#FFE066"}',7000,false,20),
  ('streak','{"en":"Your streak","fr":"Ta série","ar":"سلسلتك"}','{"en":"Share","fr":"Partager","ar":"شارك"}','flame','{"bg":"#E8590C","fg":"#FFFFFF","accent":"#FFF3BF"}',6000,false,30),
  ('trap','{"en":"Common trap","fr":"Piège classique","ar":"فخ شائع"}','{"en":"See the lesson","fr":"Voir la leçon","ar":"شاهد الدرس"}','warning','{"bg":"#C92A2A","fg":"#FFFFFF","accent":"#FFE066"}',8000,true,40),
  ('recap','{"en":"Weekly recap","fr":"Bilan de la semaine","ar":"حصيلة الأسبوع"}','{"en":"Share","fr":"Partager","ar":"شارك"}','insights','{"bg":"#5F3DC4","fg":"#FFFFFF","accent":"#FFD43B"}',7000,false,50),
  ('explainer','{"en":"In 30 seconds","fr":"En 30 secondes","ar":"في 30 ثانية"}','{"en":"See the lesson","fr":"Voir la leçon","ar":"شاهد الدرس"}','lightbulb','{"bg":"#1971C2","fg":"#FFFFFF","accent":"#FFE066"}',8000,false,60),
  ('news','{"en":"News","fr":"Actualité","ar":"أخبار"}','{"en":"Read more","fr":"En savoir plus","ar":"اقرأ المزيد"}','campaign','{"bg":"#343A40","fg":"#FFFFFF","accent":"#FFD43B"}',7000,false,70),
  ('fun','{"en":"Just for fun","fr":"Pour le plaisir","ar":"للمتعة"}','{"en":"Nice","fr":"Sympa","ar":"رائع"}','celebration','{"bg":"#AE3EC9","fg":"#FFFFFF","accent":"#FFE066"}',6000,false,80)
on conflict (type) do nothing;

create table if not exists public.kl_stories (          -- editorial posts (irregular). payload i18n; interactive question: payload.correct_index
  id            uuid primary key default gen_random_uuid(),
  template      text not null references public.kl_story_templates(type),
  payload       jsonb not null default '{}'::jsonb,
  module_id     bigint references public.study_modules(id) on delete cascade,
  speciality_id int,
  academic_year text,
  publish_at    timestamptz not null default now(),
  expires_at    timestamptz,                             -- null = publish_at + 24 h; never longer than 24 h
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);
create index if not exists kl_stories_live_idx on public.kl_stories (publish_at desc) where active;

create table if not exists public.kl_story_daily (       -- what the server served to a student (so answers can be verified offline)
  user_id     uuid not null references public.profiles(id) on delete cascade,
  story_key   text not null,
  day         date not null,
  module_id   bigint,
  question_id bigint,
  lesson_id   bigint,
  created_at  timestamptz not null default now(),
  primary key (user_id, story_key)
);
create table if not exists public.kl_story_views (
  user_id   uuid not null references public.profiles(id) on delete cascade,
  story_key text not null,
  viewed_at timestamptz not null default now(),
  primary key (user_id, story_key)
);
create table if not exists public.kl_story_answers (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  story_key   text not null,
  question_id bigint,
  choice      int  not null check (choice >= 0),
  is_correct  boolean not null,
  day         date not null default public.algiers_today(),
  created_at  timestamptz not null default now(),
  primary key (user_id, story_key)
);
create index if not exists kl_story_answers_q_idx on public.kl_story_answers (question_id, day);

-- one more notification kind: the Question of the day (the ONE daily push, filled by the app like the others)
do $k33$
declare c text;
begin
  select conname into c from pg_constraint
   where conrelid = 'public.kl_notification_templates'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%due_cards%';
  if c is not null then execute format('alter table public.kl_notification_templates drop constraint %I', c); end if;
  alter table public.kl_notification_templates add constraint kl_notification_templates_kind_check
    check (kind in ('due_cards','new_lesson','streak','generic','second_chance','exam_season','story_qotd'));
end
$k33$;
insert into public.kl_notification_templates (kind, lang, title, body) values
  ('story_qotd','en','{name}, today''s question is ready','One quick question from {module}.'),
  ('story_qotd','fr','{name}, la question du jour est prête','Une question rapide en {module}.'),
  ('story_qotd','ar','{name}، سؤال اليوم جاهز','سؤال سريع في {module}.')
on conflict (kind, lang, body) do nothing;

-- =============================================================================
-- PART 3  SECURITY (students read config + own rows; every write goes through functions)
-- =============================================================================
do $s33$
declare t text;
begin
  foreach t in array array['kl_coin_rules','kl_coin_ledger','kl_shop_items','kl_user_inventory','kl_user_streak','kl_invite_codes','kl_invites',
                           'kl_story_templates','kl_stories','kl_story_daily','kl_story_views','kl_story_answers'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke insert, update, delete, truncate on public.%I from authenticated', t);
  end loop;
end
$s33$;
drop policy if exists "shop read" on public.kl_shop_items;
create policy "shop read" on public.kl_shop_items for select to authenticated using (active);
drop policy if exists "story templates read" on public.kl_story_templates;
create policy "story templates read" on public.kl_story_templates for select to authenticated using (active);
drop policy if exists "ledger own read" on public.kl_coin_ledger;
create policy "ledger own read" on public.kl_coin_ledger for select to authenticated using (user_id = auth.uid());
drop policy if exists "inventory own read" on public.kl_user_inventory;
create policy "inventory own read" on public.kl_user_inventory for select to authenticated using (user_id = auth.uid());
drop policy if exists "streak own read" on public.kl_user_streak;
create policy "streak own read" on public.kl_user_streak for select to authenticated using (user_id = auth.uid());

-- =============================================================================
-- PART 4  COIN ENGINE (internal functions)
-- =============================================================================
create or replace function public._award_coins(p_uid uuid, p_reason text, p_ref text)
returns int language plpgsql security definer set search_path = public as $f$
declare r public.kl_coin_rules; today date := public.algiers_today(); amt int; used int; n int;
begin
  perform pg_advisory_xact_lock(hashtextextended('klcoin:' || p_uid::text, 0));
  select * into r from public.kl_coin_rules where reason = p_reason and active;
  if r.reason is null or r.amount <= 0 then return 0; end if;
  amt := r.amount;
  if r.daily_cap is not null then
    select coalesce(sum(l.amount), 0) into used from public.kl_coin_ledger l
     where l.user_id = p_uid and l.day = today and l.reason = p_reason and l.amount > 0;
    amt := least(amt, r.daily_cap - used);
  end if;
  if r.in_global_cap then
    select coalesce(sum(l.amount), 0) into used from public.kl_coin_ledger l
      join public.kl_coin_rules x on x.reason = l.reason and x.in_global_cap
     where l.user_id = p_uid and l.day = today and l.amount > 0;
    amt := least(amt, public._cfg_int('coins_daily_cap', 100) - used);
  end if;
  if amt <= 0 then return 0; end if;
  insert into public.kl_coin_ledger (user_id, amount, reason, ref, day) values (p_uid, amt, p_reason, p_ref, today)
  on conflict (user_id, reason, ref) do nothing;
  get diagnostics n = row_count;
  return case when n = 1 then amt else 0 end;
end
$f$;

-- streak freezes: a missed gap of 1..freeze_max_gap_days days is bridged when the student owns enough freezes (1 per day)
create or replace function public._touch_activity(p_user uuid, p_xp integer default 0)
returns void language plpgsql security definer set search_path = public as $f$
declare
  today date := public.algiers_today();
  st    public.study_stats;
  streak integer; missed integer; fz integer;
begin
  insert into public.study_stats (user_id) values (p_user) on conflict (user_id) do nothing;
  select * into st from public.study_stats where user_id = p_user for update;

  streak := coalesce(st.current_streak, 0);
  if st.last_active_date is distinct from today then
    if st.last_active_date = today - 1 then
      streak := streak + 1;
    else
      missed := case when st.last_active_date is null then null else today - st.last_active_date - 1 end;
      select u.freezes into fz from public.kl_user_streak u where u.user_id = p_user for update;
      if missed is not null and streak > 0 and missed between 1 and public._cfg_int('freeze_max_gap_days', 3) and coalesce(fz, 0) >= missed then
        update public.kl_user_streak
           set freezes = freezes - missed, last_freeze_on = today, last_freeze_days = missed, updated_at = now()
         where user_id = p_user;
        streak := streak + 1;
      else
        streak := 1;
      end if;
    end if;
  end if;

  update public.study_stats
     set xp = xp + greatest(coalesce(p_xp, 0), 0),
         current_streak = streak,
         longest_streak = greatest(longest_streak, streak),
         last_active_date = today
   where user_id = p_user;

  insert into public.user_reminder_state (user_id, last_active_at, step)
  values (p_user, now(), 0)
  on conflict (user_id) do update set last_active_at = now(), step = 0;
end
$f$;

create or replace function public._streak_state(p_uid uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $f$
declare
  today date := public.algiers_today(); st public.study_stats; fz int; lf date; lfd int; eff int := 0; prot boolean := false; missed int;
begin
  select * into st from public.study_stats where user_id = p_uid;
  select u.freezes, u.last_freeze_on, u.last_freeze_days into fz, lf, lfd from public.kl_user_streak u where u.user_id = p_uid;
  fz := coalesce(fz, 0);
  if st.user_id is not null and st.last_active_date is not null then
    eff := coalesce(st.current_streak, 0);
    if st.last_active_date < today - 1 then
      missed := today - st.last_active_date - 1;
      if eff > 0 and missed <= public._cfg_int('freeze_max_gap_days', 3) and fz >= missed then prot := true; else eff := 0; end if;
    end if;
  end if;
  return jsonb_build_object('current', eff, 'best', coalesce(st.longest_streak, 0), 'freezes', fz, 'protected', prot,
                            'studied_today', coalesce(st.last_active_date = today, false),
                            'freeze_used_today', coalesce(lf = today, false),
                            'freeze_days_covered', case when lf = today then lfd end);
end
$f$;

create or replace function public._streak_milestone(p_uid uuid)
returns int language plpgsql security definer set search_path = public as $f$
declare today date := public.algiers_today(); st public.study_stats; r record; total int := 0;
begin
  select * into st from public.study_stats where user_id = p_uid;
  if st.last_active_date is distinct from today or coalesce(st.current_streak, 0) < 1 then return 0; end if;
  for r in select k.reason from public.kl_coin_rules k
            where k.active and case when k.reason ~ '^streak_[0-9]+$' then substring(k.reason from 8)::int end = st.current_streak loop
    total := total + public._award_coins(p_uid, r.reason, 'start:' || (today - (st.current_streak - 1))::text);
  end loop;
  return total;
end
$f$;

-- called by sync_progress after every applied op; it must NEVER break the op (own exception block)
create or replace function public._coins_after_op(p_uid uuid, p_op uuid, p_kind text, pl jsonb)
returns int language plpgsql security definer set search_path = public as $f$
declare total int := 0; today date := public.algiers_today(); b int; secs int; goal int; pid bigint;
begin
  begin
    if p_kind = 'review' then
      if coalesce((pl ->> 'correct')::boolean, false) then
        select p.box into b from public.learn_card_progress p where p.user_id = p_uid and p.card_id = (pl ->> 'card_id')::bigint;
        if coalesce(b, 0) >= 5 then total := total + public._award_coins(p_uid, 'card_mastered', 'card:' || (pl ->> 'card_id')); end if;
        total := total + public._award_coins(p_uid, 'card_got_it', 'op:' || p_op::text);
      end if;
    elsif p_kind = 'lesson_done' then
      total := total + public._award_coins(p_uid, 'lesson_done', 'lesson:' || (pl ->> 'lesson_id'));
    elsif p_kind = 'study_time' then
      select coalesce(d.active_seconds, 0), coalesce(p.study_goal_minutes, 30) * 60 into secs, goal
        from public.profiles p left join public.study_daily d on d.user_id = p.id and d.day = today where p.id = p_uid;
      if secs >= goal then total := total + public._award_coins(p_uid, 'daily_goal', 'day:' || today::text); end if;
    elsif p_kind = 'exam_attempt' then
      select a.paper_id into pid from public.learn_exam_attempts a
       where a.id = (pl ->> 'attempt_id')::uuid and a.user_id = p_uid and a.status = 'finished' and a.total > 0;
      if pid is not null then total := total + public._award_coins(p_uid, 'exam_selfscore', 'paper:' || pid::text); end if;
    end if;
    if p_kind not in ('app_open', 'reading_position', 'story_view') then
      total := total + public._streak_milestone(p_uid);
    end if;
  exception when others then
    raise warning 'coins hook skipped: %', sqlerrm;
    return 0;
  end;
  return total;
end
$f$;

-- =============================================================================
-- PART 5  STORY ANSWER / VIEW (sync kinds story_answer, story_view)
-- =============================================================================
create or replace function public._apply_story_view(p_uid uuid, pl jsonb)
returns void language plpgsql security definer set search_path = public as $f$
declare k text := pl ->> 'story_key';
begin
  if k is null or length(k) not between 3 and 80 then raise exception 'invalid_story'; end if;
  insert into public.kl_story_views (user_id, story_key) values (p_uid, k) on conflict do nothing;
end
$f$;

create or replace function public._apply_story_answer(p_uid uuid, p_op uuid, pl jsonb)
returns int language plpgsql security definer set search_path = public as $f$
declare
  k text := pl ->> 'story_key'; ch int; sd public.kl_story_daily; s public.kl_stories; r jsonb; ok boolean; qid bigint; n int;
begin
  if k is null or length(k) not between 3 and 80 then raise exception 'invalid_story'; end if;
  begin ch := (pl ->> 'choice')::int; exception when others then raise exception 'invalid_choice'; end;
  if ch is null or ch < 0 then raise exception 'invalid_choice'; end if;
  if exists (select 1 from public.kl_story_answers a where a.user_id = p_uid and a.story_key = k) then return 0; end if;   -- already answered

  if k like 'qotd:%' then
    select * into sd from public.kl_story_daily d where d.user_id = p_uid and d.story_key = k;
    if sd.user_id is null or sd.question_id is null then raise exception 'story_not_found'; end if;
    if sd.day < public.algiers_today() - 3 then raise exception 'story_expired'; end if;
    qid := sd.question_id;
    r := public.submit_answer(qid, ch);                       -- records the attempt, XP, streak day, pulls cards back on a miss
    ok := coalesce((r ->> 'correct')::boolean, false);
  elsif k like 'ed:%' then
    begin select * into s from public.kl_stories x where x.id = substring(k from 4)::uuid and x.active;
    exception when others then raise exception 'story_not_found'; end;
    if s.id is null then raise exception 'story_not_found'; end if;
    if not (s.payload ? 'correct_index') then raise exception 'not_a_question'; end if;
    if now() > s.publish_at + interval '72 hours' then raise exception 'story_expired'; end if;
    ok := (ch = (s.payload ->> 'correct_index')::int);
    perform public._touch_activity(p_uid, case when ok then 2 else 1 end);
  else
    raise exception 'invalid_story';
  end if;

  insert into public.kl_story_answers (user_id, story_key, question_id, choice, is_correct)
  values (p_uid, k, qid, ch, ok) on conflict do nothing;
  get diagnostics n = row_count;
  if n = 1 and ok then return public._award_coins(p_uid, 'story_question_right', k); end if;
  return 0;
end
$f$;

-- =============================================================================
-- PART 6  PATCH sync_progress IN PLACE (same technique as files 22/25): kinds story_answer + story_view, coins per op
--         result per op gets an extra key "coins" (int, 0 when none)
-- =============================================================================
do $p33$
declare
  fdef text; m1 text; m2 text; m3 text; m4 text; m5 text;
begin
  select pg_get_functiondef(to_regprocedure('public.sync_progress(jsonb)')) into fdef;
  if position('story_answer' in fdef) > 0 then raise notice 'sync_progress already patched'; return; end if;
  m1 := E'  v_msg   text;';
  m2 := E'    v_kind := item ->> ''kind'';';
  m3 := E'      elsif v_kind in (''like'', ''save'') then';
  m4 := E'      v_st := ''applied''; v_msg := null;';
  m5 := E'    results := results || jsonb_build_object(''op_id'', v_id, ''status'', v_st, ''message'', v_msg);';
  if (length(fdef) - length(replace(fdef, m1, ''))) <> length(m1) then raise exception 'sync_progress marker 1 not unique: send it to the lead'; end if;
  if (length(fdef) - length(replace(fdef, m2, ''))) <> length(m2) then raise exception 'sync_progress marker 2 not unique: send it to the lead'; end if;
  if (length(fdef) - length(replace(fdef, m3, ''))) <> length(m3) then raise exception 'sync_progress marker 3 not unique: send it to the lead'; end if;
  if (length(fdef) - length(replace(fdef, m4, ''))) <> length(m4) then raise exception 'sync_progress marker 4 not unique: send it to the lead'; end if;
  if (length(fdef) - length(replace(fdef, m5, ''))) <> length(m5) then raise exception 'sync_progress marker 5 not unique: send it to the lead'; end if;
  fdef := replace(fdef, m1, m1 || E'\n  v_coins integer := 0;');
  fdef := replace(fdef, m2, m2 || E'\n    v_coins := 0;');
  fdef := replace(fdef, m3, E'      elsif v_kind = ''story_answer'' then\n        v_coins := public._apply_story_answer(uid, v_id, v_pl);\n'
                         || E'      elsif v_kind = ''story_view'' then\n        perform public._apply_story_view(uid, v_pl);\n' || m3);
  fdef := replace(fdef, m4, E'      v_coins := v_coins + public._coins_after_op(uid, v_id, v_kind, v_pl);\n' || m4);
  fdef := replace(fdef, m5, E'    results := results || jsonb_build_object(''op_id'', v_id, ''status'', v_st, ''message'', v_msg, ''coins'', case when v_st = ''applied'' then v_coins else 0 end);');
  execute fdef;
end
$p33$;

-- =============================================================================
-- PART 7  RPCs: wallet, shop, stories
-- =============================================================================
create or replace function public.get_wallet()
returns jsonb language plpgsql stable security definer set search_path = public as $f$
declare
  uid uuid := auth.uid(); today date := public.algiers_today(); bal int; earned int; cap int := public._cfg_int('coins_daily_cap', 100); inv jsonb;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select coalesce(sum(l.amount), 0) into bal from public.kl_coin_ledger l where l.user_id = uid;
  select coalesce(sum(l.amount), 0) into earned from public.kl_coin_ledger l
    join public.kl_coin_rules x on x.reason = l.reason and x.in_global_cap
   where l.user_id = uid and l.day = today and l.amount > 0;
  select coalesce(jsonb_agg(jsonb_build_object('item_id', i.item_id, 'kind', s.kind, 'equipped', i.equipped) order by i.acquired_at), '[]'::jsonb)
    into inv from public.kl_user_inventory i join public.kl_shop_items s on s.id = i.item_id where i.user_id = uid;
  return jsonb_build_object('balance', bal, 'today_earned', earned, 'daily_cap', cap, 'cap_remaining', greatest(cap - earned, 0),
                            'max_freezes', public._cfg_int('coins_max_freezes', 2),
                            'streak', public._streak_state(uid), 'inventory', inv);
end
$f$;

create or replace function public.buy_item(p_item text)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare uid uuid := auth.uid(); it public.kl_shop_items; bal int; fz int;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(hashtextextended('klcoin:' || uid::text, 0));
  select * into it from public.kl_shop_items where id = p_item;
  if it.id is null then raise exception 'item_not_found'; end if;
  if not it.active then raise exception 'item_inactive'; end if;
  if it.kind = 'streak_freeze' then
    insert into public.kl_user_streak (user_id) values (uid) on conflict do nothing;
    select u.freezes into fz from public.kl_user_streak u where u.user_id = uid for update;
    if fz >= public._cfg_int('coins_max_freezes', 2) then raise exception 'freeze_limit'; end if;
  elsif exists (select 1 from public.kl_user_inventory i where i.user_id = uid and i.item_id = it.id) then
    raise exception 'already_owned';
  end if;
  select coalesce(sum(l.amount), 0) into bal from public.kl_coin_ledger l where l.user_id = uid;
  if bal < it.price then raise exception 'insufficient_coins'; end if;
  if it.price > 0 then
    insert into public.kl_coin_ledger (user_id, amount, reason, ref) values (uid, -it.price, 'shop_buy', 'buy:' || gen_random_uuid()::text);
  end if;
  if it.kind = 'streak_freeze' then
    update public.kl_user_streak set freezes = freezes + 1, updated_at = now() where user_id = uid returning freezes into fz;
  else
    insert into public.kl_user_inventory (user_id, item_id) values (uid, it.id);
  end if;
  return jsonb_build_object('item_id', it.id, 'balance', bal - it.price, 'freezes', fz);
end
$f$;

create or replace function public.equip_item(p_item text, p_on boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare uid uuid := auth.uid(); k text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select s.kind into k from public.kl_user_inventory i join public.kl_shop_items s on s.id = i.item_id where i.user_id = uid and i.item_id = p_item;
  if k is null then raise exception 'not_owned'; end if;
  if coalesce(p_on, true) then
    update public.kl_user_inventory i set equipped = false
     where i.user_id = uid and i.item_id in (select s.id from public.kl_shop_items s where s.kind = k);
  end if;
  update public.kl_user_inventory set equipped = coalesce(p_on, true) where user_id = uid and item_id = p_item;
  return jsonb_build_object('item_id', p_item, 'equipped', coalesce(p_on, true));
end
$f$;

create or replace function public._module_card(p_mod bigint)
returns jsonb language sql stable security definer set search_path = public as $f$
  select jsonb_build_object('id', m.id,
           'name_i18n', case when mm.name_i18n is not null and mm.name_i18n <> '{}'::jsonb then mm.name_i18n
                             else jsonb_build_object('fr', coalesce(mm.display_name, m.name)) end,
           'icon', mm.icon, 'color', mm.color)
    from public.study_modules m left join public.kl_module_meta mm on mm.module_id = m.id where m.id = p_mod
$f$;

create or replace function public.get_my_stories()
returns jsonb language plpgsql volatile security definer set search_path = public as $f$
declare
  uid uuid := auth.uid(); today date := public.algiers_today(); pr public.profiles; ulang text;
  mod bigint; frontier public.learn_lessons; frontier_open boolean := false; sd public.kl_story_daily; q public.learn_questions;
  skey text; payload jsonb; ans record; stories jsonb := '[]'::jsonb; tpls jsonb; s record; st jsonb;
  due int; secs int := public._cfg_int('story_card_seconds', 20); minutes int; cur int; nm int; nrw int;
  yq bigint; yn int; yc int; minsample int := public._cfg_int('story_min_sample', 30); bal int;
  expire_auto timestamptz := ((today + 1)::timestamp at time zone 'Africa/Algiers');
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into pr from public.profiles where id = uid;
  if pr.id is null then raise exception 'profile_missing'; end if;
  ulang := coalesce(pr.preferred_language, 'en');

  -- current module = where the student studied last; else the first module that has content
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

    -- 1) QUESTION OF THE DAY (one per day, remembered so offline answers can be verified)
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

    -- 2) YOUR PLAN (due cards + next episode + an ESTIMATED time)
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

  -- 3) STREAK
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

  -- 4) EDITORIAL (irregular), live and targeted, never older than 24 h
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
  return jsonb_build_object('day', today, 'generated_at', now(), 'language', ulang, 'balance', bal, 'templates', tpls, 'stories', stories);
end
$f$;

-- =============================================================================
-- PART 8  PERMISSIONS
-- =============================================================================
do $g33$
declare f text;
begin
  foreach f in array array['public._cfg_int(text,integer)','public._award_coins(uuid,text,text)','public._streak_state(uuid)','public._streak_milestone(uuid)',
      'public._coins_after_op(uuid,uuid,text,jsonb)','public._apply_story_view(uuid,jsonb)','public._apply_story_answer(uuid,uuid,jsonb)',
      'public._module_card(bigint)','public._touch_activity(uuid,integer)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['public.get_wallet()','public.buy_item(text)','public.equip_item(text,boolean)','public.get_my_stories()','public.sync_progress(jsonb)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$g33$;
notify pgrst, 'reload schema';
