-- =============================================================================
-- KAMPUSLINK BACKEND  |  04  V1 SECURITY (row security, policies, grants, realtime)
-- =============================================================================
-- Run AFTER 03 (policies call is_admin / user_in_module). Re-runnable.
-- MODEL: the app READS through these policies and WRITES only through the functions of
-- file 03. So most tables get a SELECT policy only, and direct INSERT/UPDATE/DELETE rights
-- are removed.
-- After this file: run the Store check (runbook A7). This file changes ONE thing the Store
-- could notice: other people's profile rows are no longer readable directly (the Store only
-- reads its own row's is_admin, and its server functions run as definer, so it is not
-- affected - the check proves it).
-- =============================================================================


-- =============================================================================
-- PART 1  PROFILES: stop leaking fcm_token / is_admin to every signed-in user
-- =============================================================================
drop policy if exists "Authenticated users can view all profiles" on public.profiles;
-- kept: "Users can view own profile", "Users can insert own profile", "Users can update own profile"

-- the safe, public card of a student (chat names, avatars). Owner-run view = reads all rows
-- but exposes ONLY these columns.
create or replace view public.public_profiles as
select p.id, p.username, p.avatar_url, p.avatar_blurhash,
       p.university_id, p.speciality_id, p.academic_year, p.created_at
from public.profiles p
where p.onboarding_complete;

revoke all on public.public_profiles from anon, authenticated;
grant select on public.public_profiles to authenticated;


-- =============================================================================
-- PART 2  NEW TABLES: enable row security + read policies
-- =============================================================================
-- app_config: everyone can read (NEVER put secrets in it), only admins write
alter table public.app_config enable row level security;
drop policy if exists "config read" on public.app_config;
create policy "config read" on public.app_config for select to anon, authenticated using (true);
drop policy if exists "config admin write" on public.app_config;
create policy "config admin write" on public.app_config for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- push_tokens: no client access at all (service role / functions only)
alter table public.push_tokens enable row level security;

alter table public.user_reminder_state enable row level security;
drop policy if exists "reminder own read" on public.user_reminder_state;
create policy "reminder own read" on public.user_reminder_state for select to authenticated
  using (user_id = auth.uid());

alter table public.study_daily enable row level security;
drop policy if exists "daily own read" on public.study_daily;
create policy "daily own read" on public.study_daily for select to authenticated
  using (user_id = auth.uid());

alter table public.module_chat_messages enable row level security;
drop policy if exists "chat member read" on public.module_chat_messages;
create policy "chat member read" on public.module_chat_messages for select to authenticated
  using (deleted_at is null and public.user_in_module(module_id));
drop policy if exists "chat admin read" on public.module_chat_messages;
create policy "chat admin read" on public.module_chat_messages for select to authenticated
  using (public.is_admin());

alter table public.message_translations enable row level security;
drop policy if exists "translation member read" on public.message_translations;
create policy "translation member read" on public.message_translations for select to authenticated
  using (exists (select 1 from public.module_chat_messages m
                  where m.id = message_id and m.deleted_at is null
                    and public.user_in_module(m.module_id)));

alter table public.module_glossary enable row level security;
drop policy if exists "glossary member read" on public.module_glossary;
create policy "glossary member read" on public.module_glossary for select to authenticated
  using (public.user_in_module(module_id));

alter table public.learn_card_likes enable row level security;
drop policy if exists "card like own read" on public.learn_card_likes;
create policy "card like own read" on public.learn_card_likes for select to authenticated
  using (user_id = auth.uid());

alter table public.learn_card_saves enable row level security;
drop policy if exists "card save own read" on public.learn_card_saves;
create policy "card save own read" on public.learn_card_saves for select to authenticated
  using (user_id = auth.uid());

alter table public.learn_card_comments enable row level security;
drop policy if exists "card comment member read" on public.learn_card_comments;
create policy "card comment member read" on public.learn_card_comments for select to authenticated
  using (deleted_at is null
         and exists (select 1 from public.learn_cards c
                       join public.learn_lessons l on l.id = c.lesson_id
                      where c.id = card_id and l.status = 'published'
                        and public.user_in_module(l.module_id)));

alter table public.learn_quiz_attempts enable row level security;
drop policy if exists "attempt own read" on public.learn_quiz_attempts;
create policy "attempt own read" on public.learn_quiz_attempts for select to authenticated
  using (user_id = auth.uid());

alter table public.module_content_versions enable row level security;
drop policy if exists "version member read" on public.module_content_versions;
create policy "version member read" on public.module_content_versions for select to authenticated
  using (public.user_in_module(module_id));

alter table public.learn_lesson_resources enable row level security;
drop policy if exists "lesson resource member read" on public.learn_lesson_resources;
create policy "lesson resource member read" on public.learn_lesson_resources for select to authenticated
  using (exists (select 1 from public.learn_lessons l
                  where l.id = lesson_id and l.status = 'published'
                    and public.user_in_module(l.module_id)));


-- =============================================================================
-- PART 3  EXISTING TABLES: tighten to the new model
-- =============================================================================
-- library: members of the module read visible files; uploads go through add_module_resource()
-- and post_chat_message() only
drop policy if exists "study_resources_select_all" on public.study_resources;
drop policy if exists "study_resources_insert_own" on public.study_resources;
drop policy if exists "library member read" on public.study_resources;
create policy "library member read" on public.study_resources for select to authenticated
  using (status = 'visible' and public.user_in_module(module_id));

-- upvotes: only through toggle_resource_upvote() (it keeps the counter right)
drop policy if exists "study_upvotes_insert_own" on public.study_resource_upvotes;
drop policy if exists "study_upvotes_delete_own" on public.study_resource_upvotes;
drop policy if exists "study_upvotes_select_all" on public.study_resource_upvotes;
drop policy if exists "upvote own read" on public.study_resource_upvotes;
create policy "upvote own read" on public.study_resource_upvotes for select to authenticated
  using (user_id = auth.uid());

-- progress: written only by review_card / submit_answer / complete_lesson
drop policy if exists "learn_card_progress_own" on public.learn_card_progress;
drop policy if exists "card progress own read" on public.learn_card_progress;
create policy "card progress own read" on public.learn_card_progress for select to authenticated
  using (user_id = auth.uid());
drop policy if exists "learn_lesson_progress_own" on public.learn_lesson_progress;
drop policy if exists "lesson progress own read" on public.learn_lesson_progress;
create policy "lesson progress own read" on public.learn_lesson_progress for select to authenticated
  using (user_id = auth.uid());

-- notifications: own rows only (policies from runbook A4, re-created here so this file is complete)
alter table public.notifications enable row level security;
drop policy if exists "own notifications read" on public.notifications;
create policy "own notifications read" on public.notifications for select to authenticated
  using (auth.uid() = user_id);
drop policy if exists "own notifications update" on public.notifications;
create policy "own notifications update" on public.notifications for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own notifications delete" on public.notifications;
create policy "own notifications delete" on public.notifications for delete to authenticated
  using (auth.uid() = user_id);


-- =============================================================================
-- PART 4  GRANTS: only what each role really needs
-- =============================================================================
-- never needed by the API on any table (the REST API cannot reach TRUNCATE anyway)
revoke truncate, trigger, references on all tables in schema public from anon, authenticated;

-- new tables: no anon, read-only for signed-in users (writes happen in functions)
revoke all on public.push_tokens from anon, authenticated;

revoke all on public.user_reminder_state, public.study_daily,
              public.module_chat_messages, public.message_translations, public.module_glossary,
              public.learn_card_likes, public.learn_card_saves, public.learn_card_comments,
              public.learn_quiz_attempts, public.module_content_versions,
              public.learn_lesson_resources
  from anon, authenticated;
grant select on public.user_reminder_state, public.study_daily,
                public.module_chat_messages, public.message_translations, public.module_glossary,
                public.learn_card_likes, public.learn_card_saves, public.learn_card_comments,
                public.learn_quiz_attempts, public.module_content_versions,
                public.learn_lesson_resources
  to authenticated;

-- app_config: read for everyone, write for admins (the policy decides who)
revoke all on public.app_config from anon, authenticated;
grant select on public.app_config to anon, authenticated;
grant insert, update, delete on public.app_config to authenticated;

-- existing tables that are now written by functions only
revoke insert, update, delete on public.study_resources         from anon, authenticated;
revoke select                 on public.study_resources         from anon;
revoke insert, update, delete on public.study_resource_upvotes  from anon, authenticated;
revoke all                    on public.study_resource_upvotes  from anon;
revoke insert, update, delete on public.learn_card_progress     from anon, authenticated;
revoke insert, update, delete on public.learn_lesson_progress   from anon, authenticated;
revoke all                    on public.learn_card_progress     from anon;
revoke all                    on public.learn_lesson_progress   from anon;


-- =============================================================================
-- PART 5  REALTIME: live chat (row security still decides who receives what)
-- =============================================================================
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.module_chat_messages;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.message_translations;
    exception when duplicate_object then null;
    end;
  end if;
end $$;
