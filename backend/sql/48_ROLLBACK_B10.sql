-- 48_ROLLBACK_B10.sql: bodies BEFORE file 48 (production 14 Nov 2026). Run only to undo 48.
CREATE OR REPLACE FUNCTION public.review_card(p_card bigint, p_correct boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid    uuid := auth.uid();
  cur    public.learn_card_progress;
  newbox integer;
  wait   interval;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.learn_cards c
    join public.learn_lessons l on l.id = c.lesson_id
    where c.id = p_card and l.status = 'published' and public.user_in_module(l.module_id)
  ) then raise exception 'card_not_available'; end if;

  select * into cur from public.learn_card_progress
   where user_id = uid and card_id = p_card;

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

  perform public._touch_activity(uid, case when p_correct then 2 else 1 end);
  return jsonb_build_object('box', newbox, 'due_at', now() + wait);
end $function$
;
CREATE OR REPLACE FUNCTION public.submit_answer(p_question bigint, p_choice integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid uuid := auth.uid();
  q   public.learn_questions;
  les public.learn_lessons;
  ok  boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into q from public.learn_questions where id = p_question;
  if q.id is null then raise exception 'question_not_found'; end if;
  select * into les from public.learn_lessons where id = q.lesson_id and status = 'published';
  if les.id is null or not public.user_in_module(les.module_id) then
    raise exception 'not_available';
  end if;

  ok := (p_choice = q.correct_index);
  insert into public.learn_quiz_attempts (user_id, lesson_id, question_id, chosen_index, is_correct)
  values (uid, les.id, q.id, p_choice, ok);

  if not ok then
    insert into public.learn_card_progress (user_id, card_id, box, due_at)
    select uid, c.id, 1, now() from public.learn_cards c where c.lesson_id = les.id
    on conflict (user_id, card_id) do update set box = 1, due_at = now();
  end if;

  perform public._touch_activity(uid, case when ok then 3 else 1 end);
  return jsonb_build_object('correct', ok, 'correct_index', q.correct_index);
end $function$
;
CREATE OR REPLACE FUNCTION public._apply_content_report(p_uid uuid, pl jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    select count(distinct r.user_id) into n from public.content_reports r
     where r.target_type = t and r.target_id = tid and r.status = 'open';
    if n >= 3 then
      if t = 'card'        then update public.learn_cards     set hidden = true where id = tid::bigint and not hidden;
      elsif t = 'question' then update public.learn_questions set hidden = true where id = tid::bigint and not hidden;
      elsif t = 'set'      then update public.learn_card_sets set hidden = true where id = tid::bigint and not hidden;
      else                      update public.learn_practice  set hidden = true where id = tid::bigint and not hidden;
      end if;
      insert into public.module_content_versions (module_id, version, updated_at) values (mid, 1, now())
      on conflict (module_id) do update set version = public.module_content_versions.version + 1, updated_at = now();
    end if;
  end if;
end $function$
;
CREATE OR REPLACE FUNCTION public._touch_activity(p_user uuid, p_xp integer DEFAULT 0)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$
;
