-- =====================================================================
-- 42_B02_SECURITY_LOCKDOWN.sql   (B02 - C-02, C-03, C-14, C-18, C-22 + Pass C Q1/Q2)
-- Run ONCE in the Supabase SQL editor (whole file). Safe to re-run.
-- Kampus Store objects (kampus_store_*, ks_*, set_costs, set_product_slug, apply_sync) are NOT touched: flagged only.
-- The last SELECT shows what was done, what was skipped, and a verification list.
-- C-23 (due_reminders filters): not changed - it is closed to users here and push moves to Cloudflare; drop in B19.
-- =====================================================================
create temp table if not exists b02_log(n serial, step text, obj text, action text);
truncate b02_log;

do $b02$
declare
  r record; v_users text; v_store text := '^(ks_|kampus_store)|^(set_costs|set_product_slug|apply_sync)$';
  v_tbl text; v_has_admin boolean;
begin
  -- 1) Q2: anon must not write any table (store + tables with an open write policy are skipped).
  for r in select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind in ('r','p','v') order by 1 loop
    if r.relname ~ v_store then
      insert into b02_log(step,obj,action) values ('1 anon writes', r.relname, 'SKIPPED: store'); continue;
    end if;
    if exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = r.relname
               and p.cmd in ('INSERT','UPDATE','DELETE','ALL')
               and ('anon' = any(p.roles) or 'public' = any(p.roles))
               and coalesce(p.qual,'') || ' ' || coalesce(p.with_check,'') !~* '(auth\.uid|auth\.jwt|is_admin|auth\.role)') then
      insert into b02_log(step,obj,action) values ('1 anon writes', r.relname, 'SKIPPED: open write policy - check by hand'); continue;
    end if;
    execute format('revoke insert, update, delete, truncate, references, trigger on public.%I from anon', r.relname);
  end loop;
  insert into b02_log(step,obj,action) values ('1 anon writes', 'all other public tables', 'anon writes revoked');

  -- 2) C-02 profiles: users may only change study_goal_minutes directly.
  revoke insert, update, delete, truncate on public.profiles from anon, authenticated;
  for r in select attname from pg_attribute where attrelid = 'public.profiles'::regclass and attnum > 0 and not attisdropped loop
    execute format('revoke update (%I), insert (%I) on public.profiles from anon, authenticated', r.attname, r.attname);
  end loop;
  grant update (study_goal_minutes) on public.profiles to authenticated;
  if not exists (select 1 from pg_constraint where conname = 'profiles_study_goal_range') then
    alter table public.profiles add constraint profiles_study_goal_range
      check (study_goal_minutes is null or study_goal_minutes between 5 and 600) not valid;
  end if;
  insert into b02_log(step,obj,action) values ('2 profiles', 'profiles', 'only UPDATE(study_goal_minutes) left for users; 5-600 check');

  -- 3) C-03 / Q1: internal helpers closed. service_role keeps execute. A helper used inside a NON-definer
  --    function stays executable for authenticated (otherwise that RPC would break).
  for r in select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) args,
                  p.prorettype = 'trigger'::regtype is_trg
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prokind = 'f'
             and (p.proname like '\_%' or p.proname like 'trg\_%'
                  or p.proname in ('due_reminders','mark_reminder_sent','bump_academic_years','algiers_today',
                                   'handle_new_user','protect_is_admin'))
           order by 2 loop
    if r.proname ~ v_store then
      insert into b02_log(step,obj,action) values ('3 functions', r.proname, 'SKIPPED: store'); continue;
    end if;
    execute format('revoke all on function public.%I(%s) from public, anon', r.proname, r.args);
    execute format('grant execute on function public.%I(%s) to service_role', r.proname, r.args);
    if r.is_trg then
      execute format('revoke all on function public.%I(%s) from authenticated', r.proname, r.args);
      continue;
    end if;
    select string_agg(distinct q.proname, ', ') into v_users
      from pg_proc q join pg_namespace qn on qn.oid = q.pronamespace
     where qn.nspname = 'public' and q.oid <> r.oid and not q.prosecdef and q.prokind = 'f'
       and q.prosrc ~ ('\m' || r.proname || '\M');
    if v_users is null then
      select string_agg(viewname, ', ') into v_users from pg_views
       where schemaname = 'public' and definition ~ ('\m' || r.proname || '\M');
    end if;
    if v_users is null then
      execute format('revoke all on function public.%I(%s) from authenticated', r.proname, r.args);
    else
      execute format('grant execute on function public.%I(%s) to authenticated', r.proname, r.args);
      insert into b02_log(step,obj,action) values ('3 functions', r.proname, 'kept for authenticated (used by: ' || v_users || ')');
    end if;
  end loop;
  insert into b02_log(step,obj,action) values ('3 functions', 'helpers', 'closed for anon/public; authenticated only where needed');

  -- 4) C-14: no direct reads of lesson/card/question tables for normal users (RPCs still work).
  if exists (select 1 from pg_proc q join pg_namespace qn on qn.oid = q.pronamespace
             where qn.nspname = 'public' and not q.prosecdef and q.prokind = 'f'
               and q.prosrc ~ '\mlearn_(lessons|lesson_i18n|cards|card_i18n|questions|question_i18n)\M') then
    insert into b02_log(step,obj,action)
      select '4 learn_* reads', q.proname, 'STEP 4 SKIPPED: non-definer function reads learn_* tables'
        from pg_proc q join pg_namespace qn on qn.oid = q.pronamespace
       where qn.nspname = 'public' and not q.prosecdef and q.prokind = 'f'
         and q.prosrc ~ '\mlearn_(lessons|lesson_i18n|cards|card_i18n|questions|question_i18n)\M';
  else
    v_has_admin := exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                           where n.nspname = 'public' and p.proname = 'is_admin' and p.pronargs = 0);
    foreach v_tbl in array array['learn_lessons','learn_lesson_i18n','learn_cards','learn_card_i18n',
                                 'learn_questions','learn_question_i18n'] loop
      if to_regclass('public.' || v_tbl) is null then continue; end if;
      execute format('drop policy if exists %I on public.%I', v_tbl || '_read', v_tbl);
      execute format('revoke select on public.%I from anon', v_tbl);
      if v_has_admin and not exists (select 1 from pg_policies where schemaname = 'public'
                                     and tablename = v_tbl and policyname = v_tbl || '_admin_read') then
        execute format('create policy %I on public.%I for select to authenticated using (public.is_admin())',
                       v_tbl || '_admin_read', v_tbl);
      end if;
      insert into b02_log(step,obj,action) values ('4 learn_* reads', v_tbl, 'read policy -> admins only');
    end loop;
  end if;

  -- 5) C-18: fixed search_path on definer functions.
  if to_regprocedure('public.handle_new_user()') is not null then
    alter function public.handle_new_user() set search_path = public;
  end if;
  if to_regprocedure('public.is_username_taken(text)') is not null then
    alter function public.is_username_taken(text) set search_path = public;
  end if;
  insert into b02_log(step,obj,action) values ('5 search_path', 'handle_new_user, is_username_taken', 'search_path = public');

  -- 6) C-22 reports: same target twice = silently ignored; max 20 per hour per reporter; details <= 1000 chars.
  if (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'reports'
        and column_name in ('reporter_id','target_type','target_id','details','created_at')) = 5 then
    execute $f$
      create or replace function public._reports_guard() returns trigger
      language plpgsql security definer set search_path = public as $g$
      begin
        if exists (select 1 from public.reports r where r.reporter_id = new.reporter_id
                   and r.target_type is not distinct from new.target_type
                   and r.target_id is not distinct from new.target_id) then
          return null;
        end if;
        if (select count(*) from public.reports r where r.reporter_id = new.reporter_id
            and r.created_at > now() - interval '1 hour') >= 20 then
          return null;
        end if;
        return new;
      end $g$ $f$;
    revoke all on function public._reports_guard() from public, anon, authenticated;
    drop trigger if exists trg_reports_guard on public.reports;
    create trigger trg_reports_guard before insert on public.reports
      for each row execute function public._reports_guard();
    create index if not exists reports_reporter_target_idx on public.reports (reporter_id, target_type, target_id);
    if not exists (select 1 from pg_constraint where conname = 'reports_details_len') then
      alter table public.reports add constraint reports_details_len
        check (details is null or char_length(details) <= 1000) not valid;
    end if;
    insert into b02_log(step,obj,action) values ('6 reports', 'reports', 'dedupe + 20/hour + details<=1000');
  else
    insert into b02_log(step,obj,action) values ('6 reports', 'reports', 'STEP 6 SKIPPED: columns differ - tell engineer');
  end if;
end
$b02$;

-- Result: log + verification (FLAG rows = store / by-hand items, not errors).
select 'log' as kind, step, obj, action from b02_log
union all
select 'CHECK anon can run', 'functions', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
       case when p.proname ~ '^(ks_|kampus_store)|^(set_costs|set_product_slug|apply_sync)$' then 'FLAG store' else 'PROBLEM' end
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prokind = 'f' and has_function_privilege('anon', p.oid, 'execute')
   and (p.proname like '\_%' or p.proname ~ '^(ks_|kampus_store|due_reminders|mark_reminder_sent|bump_academic_years|set_costs|set_product_slug|apply_sync)')
union all
select 'CHECK anon can write', 'tables', c.relname,
       case when c.relname ~ '^(ks_|kampus_store)' then 'FLAG store' else 'check by hand' end
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind in ('r','p')
   and (has_table_privilege('anon', c.oid, 'insert') or has_table_privilege('anon', c.oid, 'update')
        or has_table_privilege('anon', c.oid, 'delete'))
union all
select 'CHECK profiles update', 'columns', string_agg(column_name, ', '), 'expect: study_goal_minutes'
  from information_schema.column_privileges
 where table_schema = 'public' and table_name = 'profiles' and grantee = 'authenticated' and privilege_type = 'UPDATE'
union all
select 'CHECK learn_* select policies', tablename, policyname, coalesce(qual, '')
  from pg_policies where schemaname = 'public' and cmd in ('SELECT','ALL')
   and tablename in ('learn_lessons','learn_lesson_i18n','learn_cards','learn_card_i18n','learn_questions','learn_question_i18n')
union all
select 'FLAG', '_demo_backup_ref_clicks', 'exists', 'drop in B19 after backup check'
 where to_regclass('public._demo_backup_ref_clicks') is not null;

-- ROLLBACK (one line each, only if something breaks):
-- 1) grant insert, update, delete on public.<table> to anon;
-- 2) grant update on public.profiles to authenticated;  alter table public.profiles drop constraint profiles_study_goal_range;
-- 3) grant execute on function public.<name>(<args>) to authenticated;
-- 4) drop policy <t>_admin_read on public.<t>; create policy <t>_read on public.<t> for select using (status = 'published');
--    (i18n tables: check the old policy text in live_schema before re-creating)
-- 5) alter function public.handle_new_user() reset search_path;
-- 6) drop trigger trg_reports_guard on public.reports; alter table public.reports drop constraint reports_details_len;
