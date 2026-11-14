-- =====================================================================
-- 48_B10_XP_REPORTS.sql  (B10 - C-07, C-09, C-10). Safe to re-run.
-- 1) Daily XP cap (app_config 'xp_daily_cap', default 500 when the row is missing).
--    Review XP only when the card was new or due; quiz XP only for the first try / first correct answer
--    of a question per day. The streak still counts every activity (XP 0 still touches the day).
-- 2) Auto-hide of reported content: >= 5 reporters, each account older than 7 days with >= 10 min of
--    study time; max 5 auto-hides per module per day; never re-hides an item an admin restored.
-- 3) Founder decision: a wrong quiz answer sends lesson cards back to box 1 ONLY when the card has
--    no progress row yet (on conflict do nothing). Existing boxes are never reset.
-- Change the cap without a deploy:
--   insert into public.app_config(key, value) values ('xp_daily_cap', '800') on conflict (key) do update set value = excluded.value;
-- Rollback: 48_ROLLBACK_B10.sql (old bodies from production 14 Nov 2026).
-- =====================================================================
alter table public.study_daily add column if not exists xp integer not null default 0;

create table if not exists public.kl_auto_hides (
  id          bigserial primary key,
  module_id   bigint not null,
  target_type text   not null,
  target_id   text   not null,
  hidden_at   timestamptz not null default now()
);
create index if not exists kl_auto_hides_module_idx on public.kl_auto_hides (module_id, hidden_at);
alter table public.kl_auto_hides enable row level security;   -- no policy: only definer functions / admins via SQL
revoke all on public.kl_auto_hides from anon, authenticated;

-- 1a) _touch_activity: XP capped per Algiers day (study_daily.xp counts what was granted).
create or replace function public._touch_activity(p_user uuid, p_xp integer default 0)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  today date := public.algiers_today();
  st    public.study_stats;
  streak integer; missed integer; fz integer;
  v_cap  integer := public._cfg_int('xp_daily_cap', 500);
  v_got  integer;
  v_xp   integer := greatest(coalesce(p_xp, 0), 0);
begin
  insert into public.study_stats (user_id) values (p_user) on conflict (user_id) do nothing;
  select * into st from public.study_stats where user_id = p_user for update;

  if v_xp > 0 then
    insert into public.study_daily (user_id, day) values (p_user, today) on conflict (user_id, day) do nothing;
    select coalesce(d.xp, 0) into v_got from public.study_daily d where d.user_id = p_user and d.day = today;
    v_xp := least(v_xp, greatest(v_cap - coalesce(v_got, 0), 0));
    if v_xp > 0 then
      update public.study_daily set xp = xp + v_xp where user_id = p_user and day = today;
    end if;
  end if;

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
     set xp = xp + v_xp,
         current_streak = streak,
         longest_streak = greatest(longest_streak, streak),
         last_active_date = today
   where user_id = p_user;

  insert into public.user_reminder_state (user_id, last_active_at, step)
  values (p_user, now(), 0)
  on conflict (user_id) do update set last_active_at = now(), step = 0;
end
$function$;

-- 1b) review_card: XP only when the card is new or due.
create or replace function public.review_card(p_card bigint, p_correct boolean)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  uid    uuid := auth.uid();
  cur    public.learn_card_progress;
  newbox integer;
  wait   interval;
  v_due  boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.learn_cards c
    join public.learn_lessons l on l.id = c.lesson_id
    where c.id = p_card and l.status = 'published' and public.user_in_module(l.module_id)
  ) then raise exception 'card_not_available'; end if;

  select * into cur from public.learn_card_progress
   where user_id = uid and card_id = p_card;
  v_due := cur.user_id is null or cur.due_at is null or cur.due_at <= now();

  newbox := case when p_correct then least(coalesce(cur.box, 1) + 1, 5) else 1 end;
  wait := case newbox
            when 1 then interval '10 minutes'
            when 2 then interval '1 day'
            when 3 then interval '3 days'
            when 4 then interval '7 days'
            else interval '14 days'
          end;

  insert into public.learn_card_progress (user_id, card_id, box, due_at, last_reviewed_at, reps, lapses)
  values (uid, p_card, newbox, now() + wait, now(), 1, case when p_correct then 0 else 1 end)
  on conflict (user_id, card_id) do update
    set box = excluded.box,
        due_at = excluded.due_at,
        last_reviewed_at = now(),
        reps = public.learn_card_progress.reps + 1,
        lapses = public.learn_card_progress.lapses + case when p_correct then 0 else 1 end;

  insert into public.study_daily (user_id, day, cards_reviewed)
  values (uid, public.algiers_today(), 1)
  on conflict (user_id, day) do update
    set cards_reviewed = public.study_daily.cards_reviewed + 1;

  perform public._touch_activity(uid, case when not v_due then 0 when p_correct then 2 else 1 end);
  return jsonb_build_object('box', newbox, 'due_at', now() + wait);
end $function$;

-- 1c + 3) submit_answer (built with the real time column of learn_quiz_attempts).
do $sa$
declare v_col text;
begin
  select column_name into v_col from information_schema.columns
   where table_schema = 'public' and table_name = 'learn_quiz_attempts'
     and data_type like 'timestamp%' order by ordinal_position limit 1;
  if v_col is null then raise exception 'B10: learn_quiz_attempts has no timestamp column - tell the engineer'; end if;
  execute format($f$
create or replace function public.submit_answer(p_question bigint, p_choice integer)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  uid uuid := auth.uid();
  q   public.learn_questions;
  les public.learn_lessons;
  ok  boolean;
  v_since timestamptz := (public.algiers_today()::timestamp at time zone 'Africa/Algiers');
  v_tried boolean;
  v_right boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into q from public.learn_questions where id = p_question;
  if q.id is null then raise exception 'question_not_found'; end if;
  select * into les from public.learn_lessons where id = q.lesson_id and status = 'published';
  if les.id is null or not public.user_in_module(les.module_id) then
    raise exception 'not_available';
  end if;

  select count(*) > 0, coalesce(bool_or(a.is_correct), false) into v_tried, v_right
    from public.learn_quiz_attempts a
   where a.user_id = uid and a.question_id = q.id and a.%1$I >= v_since;

  ok := (p_choice = q.correct_index);
  insert into public.learn_quiz_attempts (user_id, lesson_id, question_id, chosen_index, is_correct)
  values (uid, les.id, q.id, p_choice, ok);

  if not ok then
    -- founder decision B10/3: only cards without progress go to box 1; existing boxes are kept.
    insert into public.learn_card_progress (user_id, card_id, box, due_at)
    select uid, c.id, 1, now() from public.learn_cards c where c.lesson_id = les.id
    on conflict (user_id, card_id) do nothing;
  end if;

  perform public._touch_activity(uid, case when ok and not v_right then 3
                                           when not ok and not v_tried then 1
                                           else 0 end);
  return jsonb_build_object('correct', ok, 'correct_index', q.correct_index);
end $function$;
$f$, v_col);
end $sa$;

-- 2) _apply_content_report: stricter auto-hide.
create or replace function public._apply_content_report(p_uid uuid, pl jsonb)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  t    text := pl ->> 'target_type';
  tid  text := pl ->> 'target_id';
  lid  bigint := nullif(pl ->> 'lesson_id', '')::bigint;
  mid  bigint;
  n    int;
begin
  if t not in ('card','question','set','lesson','block','practice','exam') or tid is null then raise exception 'invalid_report'; end if;
  if t in ('card','question','set','lesson','practice','exam') and tid !~ '^[0-9]{1,18}$' then raise exception 'invalid_report'; end if;
  if t = 'card'     then select l.module_id, l.id into mid, lid from public.learn_cards c join public.learn_lessons l on l.id = c.lesson_id where c.id = tid::bigint;
  elsif t = 'question' then select l.module_id, l.id into mid, lid from public.learn_questions q join public.learn_lessons l on l.id = q.lesson_id where q.id = tid::bigint;
  elsif t = 'set'    then select s.module_id into mid from public.learn_card_sets s where s.id = tid::bigint;
  elsif t = 'practice' then select x.module_id into mid from public.learn_practice x where x.id = tid::bigint; lid := null;
  elsif t = 'exam'   then select x.module_id into mid from public.learn_exam_papers x where x.id = tid::bigint; lid := null;
  elsif t = 'lesson' then lid := tid::bigint; select l.module_id into mid from public.learn_lessons l where l.id = lid;
  else                    select l.module_id into mid from public.learn_lessons l where l.id = lid;
  end if;
  if mid is null or not public.user_in_module(mid) then raise exception 'report_not_allowed'; end if;

  insert into public.content_reports (user_id, target_type, target_id, lesson_id, reason, note)
  values (p_uid, t, tid, lid, coalesce(pl ->> 'reason', 'other'), nullif(left(coalesce(pl ->> 'note', ''), 300), ''))
  on conflict (user_id, target_type, target_id) do update
    set reason = excluded.reason, note = excluded.note, status = 'open', created_at = now();

  if t in ('card','question','set','practice') then
    -- never re-hide what an admin restored (admin_set_hidden marks those reports 'fixed')
    if exists (select 1 from public.content_reports r
                where r.target_type = t and r.target_id = tid and r.status = 'fixed') then
      return;
    end if;
    -- trusted reporters only: account older than 7 days and at least 10 minutes of study time
    select count(distinct r.user_id) into n
      from public.content_reports r
      join auth.users u on u.id = r.user_id
     where r.target_type = t and r.target_id = tid and r.status = 'open'
       and u.created_at < now() - interval '7 days'
       and (select coalesce(sum(d.active_seconds), 0) from public.study_daily d where d.user_id = r.user_id) >= 600;
    if n >= public._cfg_int('report_auto_hide_min', 5)
       and (select count(*) from public.kl_auto_hides h
             where h.module_id = mid and h.hidden_at > now() - interval '1 day') < 5 then
      if t = 'card'        then update public.learn_cards     set hidden = true where id = tid::bigint and not hidden;
      elsif t = 'question' then update public.learn_questions set hidden = true where id = tid::bigint and not hidden;
      elsif t = 'set'      then update public.learn_card_sets set hidden = true where id = tid::bigint and not hidden;
      else                      update public.learn_practice  set hidden = true where id = tid::bigint and not hidden;
      end if;
      if found then
        insert into public.kl_auto_hides (module_id, target_type, target_id) values (mid, t, tid);
        insert into public.module_content_versions (module_id, version, updated_at) values (mid, 1, now())
        on conflict (module_id) do update set version = public.module_content_versions.version + 1, updated_at = now();
      end if;
    end if;
  end if;
end $function$;

-- Helpers stay closed (B02 rule): only definer functions call them.
revoke all on function public._touch_activity(uuid, integer) from public, anon, authenticated;
revoke all on function public._apply_content_report(uuid, jsonb) from public, anon, authenticated;
grant execute on function public._touch_activity(uuid, integer) to service_role;
grant execute on function public._apply_content_report(uuid, jsonb) to service_role;
grant execute on function public.review_card(bigint, boolean) to authenticated;
grant execute on function public.submit_answer(bigint, integer) to authenticated;

select 'B10 ready' as result, public._cfg_int('xp_daily_cap', 500) as xp_daily_cap,
       public._cfg_int('report_auto_hide_min', 5) as auto_hide_min_reporters;
