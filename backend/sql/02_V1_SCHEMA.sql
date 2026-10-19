-- =============================================================================
-- KAMPUSLINK BACKEND  |  02  V1 SCHEMA (tables, columns, constraints, triggers)
-- =============================================================================
-- Run AFTER 01. Safe to re-run (idempotent where Postgres allows).
-- Paste the whole file at once, or part by part (the PART headers).
--
-- DESIGN IN ONE PARAGRAPH
--   Reuse what exists: study_modules (curriculum), study_resources (library), the learn_*
--   tables (lessons = episodes, cards = flashcards, questions = quizzes, progress),
--   study_stats (xp/streak), notifications, reports, blocked_users.
--   Add: module chat, message translations, glossary, flashcard social, quiz attempts,
--   daily study time, push tokens, reminder state, remote config,
--   content versions (offline sync), lesson-to-file links.
--   Clients READ some tables directly (RLS) and WRITE only through functions (file 03).
-- =============================================================================


-- =============================================================================
-- PART 1  PROFILES: only what v1 onboarding needs
-- =============================================================================
-- Kept: id, username, created_at, university_id, speciality_id, avatar_url,
--       avatar_blurhash, onboarding_complete, preferred_language (en/fr/ar),
--       academic_year, is_admin (Store + admin use it), fcm_token (TEMPORARY, see end).
-- Added below. Dropped in file 01: residence_id, interest_sectors.
alter table public.profiles add column if not exists section text;
alter table public.profiles add column if not exists group_name text;
alter table public.profiles add column if not exists study_goal_minutes smallint not null default 30;
alter table public.profiles add column if not exists onboarding_version smallint not null default 0;

alter table public.profiles drop constraint if exists profiles_goal_check;
alter table public.profiles add  constraint profiles_goal_check
  check (study_goal_minutes between 5 and 480);

-- username format for new/changed rows (old test rows are not re-checked)
alter table public.profiles drop constraint if exists profiles_username_format;
alter table public.profiles add  constraint profiles_username_format
  check (username is null or username ~ '^[a-z0-9_.]{3,20}$') not valid;

-- the pilot speciality: Mining Engineering (id 2) gets learning content enabled
update public.specialities set learn_enabled = true where id = 2;


-- =============================================================================
-- PART 2  REMOTE CONFIG (non-secret settings; clients can read, only admins write)
-- =============================================================================
create table if not exists public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);
insert into public.app_config (key, value) values
  ('chat_rate_limit_per_minute',   '20'::jsonb),
  ('max_upload_mb',                '15'::jsonb),
  ('min_supported_build',          '0'::jsonb),
  ('files_base_url',               '"https://files.kampus-link.com/"'::jsonb)
on conflict (key) do nothing;


-- =============================================================================
-- PART 4  PUSH TOKENS, REMINDER LADDER, STUDY TIME   (verification was removed: Google sign-in only)
-- =============================================================================
create table if not exists public.push_tokens (
  token      text primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  platform   text not null default 'android',
  updated_at timestamptz not null default now()
);
create index if not exists push_tokens_user_idx on public.push_tokens (user_id);

-- move existing device tokens out of the (publicly readable) profiles row
insert into public.push_tokens (token, user_id)
select p.fcm_token, p.id
from public.profiles p
where p.fcm_token is not null and char_length(p.fcm_token) > 20
on conflict (token) do nothing;

create table if not exists public.user_reminder_state (
  user_id        uuid primary key references public.profiles(id) on delete cascade,
  last_active_at timestamptz not null default now(),
  step           smallint not null default 0 check (step between 0 and 4),
  last_sent_at   timestamptz,
  unsubscribed   boolean not null default false
);

create table if not exists public.study_daily (
  user_id        uuid not null references public.profiles(id) on delete cascade,
  day            date not null,
  active_seconds integer not null default 0 check (active_seconds >= 0),
  cards_reviewed integer not null default 0 check (cards_reviewed >= 0),
  primary key (user_id, day)
);


-- =============================================================================
-- PART 5  LIBRARY (study_resources) EXTENSIONS
-- =============================================================================
alter table public.study_resources add column if not exists title             text;
alter table public.study_resources add column if not exists file_hash         text;
alter table public.study_resources add column if not exists size_bytes        bigint;
alter table public.study_resources add column if not exists mime_type         text;
alter table public.study_resources add column if not exists origin            text not null default 'library_upload';
alter table public.study_resources add column if not exists status            text not null default 'visible';
alter table public.study_resources add column if not exists source_message_id uuid;

alter table public.study_resources drop constraint if exists study_resources_origin_check;
alter table public.study_resources add  constraint study_resources_origin_check
  check (origin in ('library_upload','chat_upload','official','imported'));
alter table public.study_resources drop constraint if exists study_resources_status_check;
alter table public.study_resources add  constraint study_resources_status_check
  check (status in ('visible','hidden','removed'));

-- more document types: TP and textbook, plus 'other'
alter table public.study_resources drop constraint if exists study_resources_resource_type_check;
alter table public.study_resources add  constraint study_resources_resource_type_check
  check (resource_type in ('cours','td','tp','textbook','exercices_corriges','exam','notes','memoire','other'));
alter table public.study_resources drop constraint if exists study_resources_file_format_check;
alter table public.study_resources add  constraint study_resources_file_format_check
  check (file_format in ('pdf','image_set','doc','ppt','image','sheet','other'));

-- the same file in the same module is stored once
create unique index if not exists study_resources_module_hash_uidx
  on public.study_resources (module_id, file_hash)
  where file_hash is not null and status <> 'removed';
create index if not exists study_resources_library_idx
  on public.study_resources (module_id, resource_type, created_at desc)
  where status = 'visible';


-- =============================================================================
-- PART 6  MODULE CHAT + TRANSLATIONS + GLOSSARY
-- =============================================================================
create table if not exists public.module_chat_messages (
  id          uuid primary key default gen_random_uuid(),
  module_id   bigint not null references public.study_modules(id) on delete cascade,
  user_id     uuid   not null references public.profiles(id) on delete cascade,
  body        text   not null default '' check (char_length(body) <= 4000),
  lang        text   not null default 'und' check (lang in ('ar','fr','en','und')),
  reply_to    uuid references public.module_chat_messages(id) on delete set null,
  resource_id bigint references public.study_resources(id) on delete set null,
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
-- "a message needs text or a file" is enforced inside post_chat_message() (file 03)
create index if not exists module_chat_module_idx on public.module_chat_messages (module_id, created_at desc);
create index if not exists module_chat_user_idx   on public.module_chat_messages (user_id, created_at desc);

-- a file shared in chat points back to its message (and the message points to the file)
alter table public.study_resources drop constraint if exists study_resources_source_message_fkey;
alter table public.study_resources add  constraint study_resources_source_message_fkey
  foreign key (source_message_id) references public.module_chat_messages(id) on delete set null;

create table if not exists public.message_translations (
  message_id uuid not null references public.module_chat_messages(id) on delete cascade,
  lang       text not null check (lang in ('ar','fr','en')),
  body       text not null,
  provider   text,
  created_at timestamptz not null default now(),
  primary key (message_id, lang)
);

create table if not exists public.module_glossary (
  id        bigint generated always as identity primary key,
  module_id bigint not null references public.study_modules(id) on delete cascade,
  fr        text,
  ar        text,
  en        text,
  note      text,
  check (coalesce(fr, ar, en) is not null)
);
create index if not exists module_glossary_module_idx on public.module_glossary (module_id);


-- =============================================================================
-- PART 7  FLASHCARD SOCIAL, QUIZ ATTEMPTS, LESSON FILE LINKS
-- =============================================================================
create table if not exists public.learn_card_likes (
  card_id    bigint not null references public.learn_cards(id) on delete cascade,
  user_id    uuid   not null references public.profiles(id)    on delete cascade,
  created_at timestamptz not null default now(),
  primary key (card_id, user_id)
);
create table if not exists public.learn_card_saves (
  card_id    bigint not null references public.learn_cards(id) on delete cascade,
  user_id    uuid   not null references public.profiles(id)    on delete cascade,
  created_at timestamptz not null default now(),
  primary key (card_id, user_id)
);
create table if not exists public.learn_card_comments (
  id         uuid primary key default gen_random_uuid(),
  card_id    bigint not null references public.learn_cards(id) on delete cascade,
  user_id    uuid   not null references public.profiles(id)    on delete cascade,
  parent_id  uuid references public.learn_card_comments(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists learn_card_comments_card_idx on public.learn_card_comments (card_id, created_at);

create table if not exists public.learn_quiz_attempts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid   not null references public.profiles(id)        on delete cascade,
  lesson_id    bigint not null references public.learn_lessons(id)   on delete cascade,
  question_id  bigint not null references public.learn_questions(id) on delete cascade,
  chosen_index integer not null,
  is_correct   boolean not null,
  created_at   timestamptz not null default now()
);
create index if not exists learn_quiz_attempts_user_idx   on public.learn_quiz_attempts (user_id, created_at desc);
create index if not exists learn_quiz_attempts_lesson_idx on public.learn_quiz_attempts (lesson_id);

-- which TD / TP / exam files belong to which episode
create table if not exists public.learn_lesson_resources (
  lesson_id   bigint not null references public.learn_lessons(id)   on delete cascade,
  resource_id bigint not null references public.study_resources(id) on delete cascade,
  role        text not null default 'extra' check (role in ('source','td','tp','exam','extra')),
  primary key (lesson_id, resource_id)
);


-- =============================================================================
-- PART 8  OFFLINE SYNC: one version number per module
-- =============================================================================
create table if not exists public.module_content_versions (
  module_id  bigint primary key references public.study_modules(id) on delete cascade,
  version    integer not null default 1,
  updated_at timestamptz not null default now()
);

create or replace function public.trg_bump_module_version()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  mid bigint;
  r   record;
begin
  if tg_op = 'DELETE' then r := old; else r := new; end if;

  if tg_table_name in ('learn_lessons', 'study_resources') then
    mid := r.module_id;
  elsif tg_table_name in ('learn_lesson_i18n', 'learn_cards', 'learn_questions') then
    select l.module_id into mid from public.learn_lessons l where l.id = r.lesson_id;
  elsif tg_table_name = 'learn_card_i18n' then
    select l.module_id into mid
    from public.learn_cards c join public.learn_lessons l on l.id = c.lesson_id
    where c.id = r.card_id;
  elsif tg_table_name = 'learn_question_i18n' then
    select l.module_id into mid
    from public.learn_questions q join public.learn_lessons l on l.id = q.lesson_id
    where q.id = r.question_id;
  end if;

  if mid is not null then
    insert into public.module_content_versions (module_id, version, updated_at)
    values (mid, 1, now())
    on conflict (module_id) do update
      set version = public.module_content_versions.version + 1, updated_at = now();
  end if;
  return null;
end $$;

drop trigger if exists trg_bump_version on public.learn_lessons;
create trigger trg_bump_version after insert or update or delete on public.learn_lessons
  for each row execute function public.trg_bump_module_version();
drop trigger if exists trg_bump_version on public.learn_lesson_i18n;
create trigger trg_bump_version after insert or update or delete on public.learn_lesson_i18n
  for each row execute function public.trg_bump_module_version();
drop trigger if exists trg_bump_version on public.learn_cards;
create trigger trg_bump_version after insert or update or delete on public.learn_cards
  for each row execute function public.trg_bump_module_version();
drop trigger if exists trg_bump_version on public.learn_card_i18n;
create trigger trg_bump_version after insert or update or delete on public.learn_card_i18n
  for each row execute function public.trg_bump_module_version();
drop trigger if exists trg_bump_version on public.learn_questions;
create trigger trg_bump_version after insert or update or delete on public.learn_questions
  for each row execute function public.trg_bump_module_version();
drop trigger if exists trg_bump_version on public.learn_question_i18n;
create trigger trg_bump_version after insert or update or delete on public.learn_question_i18n
  for each row execute function public.trg_bump_module_version();
-- for files only real changes bump the version (not download/upvote counters)
drop trigger if exists trg_bump_version on public.study_resources;
create trigger trg_bump_version
  after insert or delete or update of status, file_urls, title, resource_type on public.study_resources
  for each row execute function public.trg_bump_module_version();


-- =============================================================================
-- PART 9  NOTIFICATIONS + REPORTS: new vocabulary
-- =============================================================================
delete from public.notifications;   -- already empty after file 01; safe if re-run
alter table public.notifications drop column if exists post_id;
alter table public.notifications drop column if exists comment_id;
alter table public.notifications drop column if exists message_id;
alter table public.notifications add column if not exists module_id bigint
  references public.study_modules(id) on delete cascade;
alter table public.notifications add column if not exists data jsonb not null default '{}'::jsonb;
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add  constraint notifications_type_check
  check (type in ('streak','reminder','module_update','chat','system'));

delete from public.reports
 where target_type not in ('user','module_message','flashcard_comment','resource');
alter table public.reports drop constraint if exists reports_target_type_check;
alter table public.reports add  constraint reports_target_type_check
  check (target_type in ('user','module_message','flashcard_comment','resource'));


-- =============================================================================
-- PART 10  LATER (do NOT run now): remove the old token column once the new app
-- registers tokens through register_push_token()
-- =============================================================================
-- alter table public.profiles drop column fcm_token;
