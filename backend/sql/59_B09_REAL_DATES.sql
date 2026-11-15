-- =====================================================================
-- 59_B09_REAL_DATES.sql  (FIX_PLAN B09 server part). Safe to re-run. Old apps: nothing changes
-- (no "at" in their ops = now(), exactly as before).
-- Offline work keeps its real day: review / answer / lesson_done / study_time ops carry "at" (app B09);
-- the server clamps it (never in the future, never older than 14 days) and counts XP, study minutes,
-- reviews and the streak on THAT day (Africa/Algiers). Work from a day before the last active day adds
-- XP to that day but never rewrites the streak. Bodies = live copies of 15 Nov + these changes only.
-- review_card / submit_answer / complete_lesson / log_study_time / _touch_activity get ONE new last
-- parameter with a default: the old 2-argument calls keep working (old functions dropped first so a
-- 2-argument call is never ambiguous).
-- =====================================================================
create or replace function public._clamp_at(p_at timestamptz)
returns timestamptz language sql stable set search_path = public as $$
  select least(now(), greatest(now() - interval '14 days', coalesce(p_at, now())))
$$;

-- "at" of an op payload; anything that is not an ISO time = now() (no exception, no sub-transaction).
create or replace function public._op_at(pl jsonb)
returns timestamptz language sql stable set search_path = public as $$
  select public._clamp_at(case
    when (pl ->> 'at') ~ '^[0-9]{4}-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9](\.[0-9]{1,9})?(Z|[+-][0-2][0-9]:?[0-5][0-9])?$'
    then (pl ->> 'at')::timestamptz end)
$$;
revoke all on function public._clamp_at(timestamptz) from public, anon, authenticated;
revoke all on function public._op_at(jsonb) from public, anon, authenticated;

drop function if exists public._touch_activity(uuid, integer);
drop function if exists public.review_card(bigint, boolean);
drop function if exists public.submit_answer(bigint, integer);
drop function if exists public.complete_lesson(bigint, integer);
drop function if exists public.log_study_time(integer);

CREATE OR REPLACE FUNCTION public._touch_activity(p_user uuid, p_xp integer DEFAULT 0, p_day date DEFAULT NULL::date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  -- B09: the day the work was DONE (offline ops arrive later); never in the future.
  today date := least(coalesce(p_day, public.algiers_today()), public.algiers_today());
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
  -- B09: work from a day BEFORE the last active day (second phone, late op) adds its XP to that day
  -- but never rewrites the streak.
  if st.last_active_date is not null and today < st.last_active_date then
    update public.study_stats set xp = xp + v_xp where user_id = p_user;
    return;
  end if;
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

CREATE OR REPLACE FUNCTION public.review_card(p_card bigint, p_correct boolean, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
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
  v_due  boolean;
  v_at   timestamptz := public._clamp_at(p_at);
  v_day  date := (v_at at time zone 'Africa/Algiers')::date;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.learn_cards c
    join public.learn_lessons l on l.id = c.lesson_id
    where c.id = p_card and l.status = 'published' and public.user_in_module(l.module_id)
  ) then raise exception 'card_not_available'; end if;

  select * into cur from public.learn_card_progress
   where user_id = uid and card_id = p_card;
  v_due := cur.user_id is null or cur.due_at is null or cur.due_at <= v_at;

  newbox := case when p_correct then least(coalesce(cur.box, 1) + 1, 5) else 1 end;
  wait := case newbox
            when 1 then interval '10 minutes'
            when 2 then interval '1 day'
            when 3 then interval '3 days'
            when 4 then interval '7 days'
            else interval '14 days'
          end;

  insert into public.learn_card_progress (user_id, card_id, box, due_at, last_reviewed_at, reps, lapses)
  values (uid, p_card, newbox, v_at + wait, v_at, 1, case when p_correct then 0 else 1 end)
  on conflict (user_id, card_id) do update
    set box = excluded.box,
        due_at = excluded.due_at,
        last_reviewed_at = excluded.last_reviewed_at,
        reps = public.learn_card_progress.reps + 1,
        lapses = public.learn_card_progress.lapses + case when p_correct then 0 else 1 end;

  insert into public.study_daily (user_id, day, cards_reviewed)
  values (uid, v_day, 1)
  on conflict (user_id, day) do update
    set cards_reviewed = public.study_daily.cards_reviewed + 1;

  perform public._touch_activity(uid, case when not v_due then 0 when p_correct then 2 else 1 end, v_day);
  return jsonb_build_object('box', newbox, 'due_at', v_at + wait);
end $function$;

CREATE OR REPLACE FUNCTION public.submit_answer(p_question bigint, p_choice integer, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
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
  v_at    timestamptz := public._clamp_at(p_at);
  v_day   date := (v_at at time zone 'Africa/Algiers')::date;
  v_since timestamptz := (v_day::timestamp at time zone 'Africa/Algiers');
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
   where a.user_id = uid and a.question_id = q.id and a.created_at >= v_since
     and a.created_at < v_since + interval '1 day';

  ok := (p_choice = q.correct_index);
  insert into public.learn_quiz_attempts (user_id, lesson_id, question_id, chosen_index, is_correct, created_at)
  values (uid, les.id, q.id, p_choice, ok, v_at);

  if not ok then
    -- founder decision B10/3: only cards without progress go to box 1; existing boxes are kept.
    insert into public.learn_card_progress (user_id, card_id, box, due_at)
    select uid, c.id, 1, v_at from public.learn_cards c where c.lesson_id = les.id
    on conflict (user_id, card_id) do nothing;
  end if;

  perform public._touch_activity(uid, case when ok and not v_right then 3
                                           when not ok and not v_tried then 1
                                           else 0 end, v_day);
  return jsonb_build_object('correct', ok, 'correct_index', q.correct_index);
end $function$;

CREATE OR REPLACE FUNCTION public.complete_lesson(p_lesson bigint, p_score integer DEFAULT NULL::integer, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid  uuid := auth.uid();
  les  public.learn_lessons;
  first_time boolean;
  nxt  bigint;
  v_at timestamptz := public._clamp_at(p_at);
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into les from public.learn_lessons where id = p_lesson and status = 'published';
  if les.id is null or not public.user_in_module(les.module_id) then
    raise exception 'not_available';
  end if;

  first_time := not exists (select 1 from public.learn_lesson_progress
                             where user_id = uid and lesson_id = p_lesson);
  insert into public.learn_lesson_progress (user_id, lesson_id, score, completed_at)
  values (uid, p_lesson, p_score, v_at)
  on conflict (user_id, lesson_id) do update
    set score = greatest(coalesce(public.learn_lesson_progress.score, 0), coalesce(excluded.score, 0));

  perform public._touch_activity(uid, case when first_time then 10 else 1 end, (v_at at time zone 'Africa/Algiers')::date);

  select l.id into nxt from public.learn_lessons l
   where l.module_id = les.module_id and l.status = 'published'
     and (l.position, l.id) > (les.position, les.id)
   order by l.position, l.id limit 1;
  return jsonb_build_object('first_time', first_time, 'next_lesson_id', nxt);
end $function$;

CREATE OR REPLACE FUNCTION public.log_study_time(p_seconds integer, p_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid   uuid := auth.uid();
  s     integer := least(greatest(coalesce(p_seconds, 0), 0), 900);
  today date := (public._clamp_at(p_at) at time zone 'Africa/Algiers')::date;
  total integer;
  goal  integer;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select coalesce(p.study_goal_minutes, 30) * 60 into goal from public.profiles p where p.id = uid;

  if s > 0 then
    insert into public.study_daily (user_id, day, active_seconds)
    values (uid, today, s)
    on conflict (user_id, day) do update
      set active_seconds = public.study_daily.active_seconds + excluded.active_seconds
    returning active_seconds into total;
    if total >= 300 then perform public._touch_activity(uid, 0, today); end if;   -- 5 active minutes = streak day
  else
    select d.active_seconds into total from public.study_daily d where d.user_id = uid and d.day = today;
  end if;
  total := coalesce(total, 0);
  return jsonb_build_object('today_seconds', total, 'goal_seconds', goal, 'goal_reached', total >= goal);
end $function$;

CREATE OR REPLACE FUNCTION public.sync_progress(p_ops jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid     uuid := auth.uid();
  item    jsonb;
  v_raw   text;
  v_id    uuid;
  v_kind  text;
  v_pl    jsonb;
  v_card  bigint;
  v_st    text;
  v_msg   text;
  v_coins integer := 0;
  v_mods  bigint[];
  v_streak boolean := false;
  results jsonb := '[]'::jsonb;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_ops is null or jsonb_typeof(p_ops) <> 'array' then raise exception 'invalid_ops'; end if;
  if jsonb_array_length(p_ops) > 200 then raise exception 'too_many_ops'; end if;

  for item in select e.value from jsonb_array_elements(p_ops) e loop
    -- B05: checked by pattern, not by a begin/exception block (one sub-transaction less per op).
    v_raw := item ->> 'op_id';
    if v_raw is null or v_raw !~* '^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$' then
      results := results || jsonb_build_object('op_id', v_raw, 'status', 'rejected', 'message', 'invalid_op_id');
      continue;
    end if;
    v_id    := v_raw::uuid;
    v_kind  := item ->> 'kind';
    v_coins := 0;
    v_pl    := coalesce(item -> 'payload', '{}'::jsonb);

    if exists (select 1 from public.client_ops c where c.user_id = uid and c.op_id = v_id) then
      results := results || jsonb_build_object('op_id', v_id, 'status', 'duplicate');
      continue;
    end if;

    begin
      if v_kind = 'review' then
        perform public.review_card((v_pl ->> 'card_id')::bigint, (v_pl ->> 'correct')::boolean, public._op_at(v_pl));
      elsif v_kind = 'answer' then
        perform public.submit_answer((v_pl ->> 'question_id')::bigint, (v_pl ->> 'choice')::integer, public._op_at(v_pl));
      elsif v_kind = 'lesson_done' then
        perform public.complete_lesson((v_pl ->> 'lesson_id')::bigint, nullif(v_pl ->> 'score', '')::integer, public._op_at(v_pl));
      elsif v_kind = 'study_time' then
        perform public.log_study_time((v_pl ->> 'seconds')::integer, public._op_at(v_pl));
      elsif v_kind = 'reading_position' then
        perform public.save_reading_position((v_pl ->> 'lesson_id')::bigint, v_pl ->> 'block_id',
                                             (v_pl ->> 'progress')::real, nullif(v_pl ->> 'at', '')::timestamptz);
      elsif v_kind = 'case_progress' then
        perform public._apply_case_progress(uid, v_pl);
      elsif v_kind = 'content_report' then
        perform public._apply_content_report(uid, v_pl);
      elsif v_kind = 'exam_attempt' then
        perform public._apply_exam_attempt(uid, v_pl);
      elsif v_kind = 'practice_progress' then
        perform public._apply_practice_progress(uid, v_pl);
      elsif v_kind = 'reminder_response' then
        perform public._apply_reminder_response(uid, v_pl);
      elsif v_kind = 'app_open' then
        perform public._apply_app_open(uid, v_pl);
      elsif v_kind = 'story_answer' then
        v_coins := public._apply_story_answer(uid, v_id, v_pl);
      elsif v_kind = 'story_view' then
        perform public._apply_story_view(uid, v_pl);
      elsif v_kind = 'helper_use' then
        perform public._apply_helper_use(uid, v_pl);
      elsif v_kind in ('like', 'save') then
        v_card := (v_pl ->> 'card_id')::bigint;
        if v_mods is null then v_mods := array(select public.my_module_ids()); end if;
        if not exists (select 1 from public.learn_cards c
                         join public.learn_lessons l on l.id = c.lesson_id
                        where c.id = v_card and l.status = 'published' and l.module_id = any(v_mods)) then
          raise exception 'card_not_available';
        end if;
        if v_kind = 'like' then
          if coalesce((v_pl ->> 'on')::boolean, true) then
            insert into public.learn_card_likes (card_id, user_id) values (v_card, uid) on conflict do nothing;
          else
            delete from public.learn_card_likes where card_id = v_card and user_id = uid;
          end if;
        else
          if coalesce((v_pl ->> 'on')::boolean, true) then
            insert into public.learn_card_saves (card_id, user_id) values (v_card, uid) on conflict do nothing;
          else
            delete from public.learn_card_saves where card_id = v_card and user_id = uid;
          end if;
        end if;
      else
        raise exception 'unknown_kind';
      end if;
      -- B05: exam achievements per exam op; the streak achievement once per call (after the loop).
      if v_kind = 'exam_attempt' then
        v_coins := v_coins + public._coins_after_op(uid, v_id, v_kind, v_pl);
      elsif v_kind not in ('app_open', 'reading_position', 'story_view') then
        v_streak := true;
      end if;
      v_st := 'applied'; v_msg := null;
    exception when others then
      -- B-17: server trouble aborts the whole call; the phone keeps the ops and retries later.
      if sqlstate in ('40001', '40P01', '55P03', '57014') then raise; end if;
      v_st := 'rejected'; v_msg := sqlerrm;
    end;

    insert into public.client_ops (user_id, op_id, kind, status, message)
    values (uid, v_id, left(coalesce(v_kind, '?'), 30), v_st, left(v_msg, 200));
    results := results || jsonb_build_object('op_id', v_id, 'status', v_st, 'message', v_msg,
                                             'coins', case when v_st = 'applied' then v_coins else 0 end);
  end loop;

  if v_streak then
    perform public._coins_after_op(uid, null, 'review', '{}'::jsonb);
  end if;
  return results;
end $function$;

revoke all on function public._touch_activity(uuid, integer, date) from public, anon, authenticated;
revoke all on function public.review_card(bigint, boolean, timestamptz) from public, anon;
revoke all on function public.submit_answer(bigint, integer, timestamptz) from public, anon;
revoke all on function public.complete_lesson(bigint, integer, timestamptz) from public, anon;
revoke all on function public.log_study_time(integer, timestamptz) from public, anon;
grant execute on function public.review_card(bigint, boolean, timestamptz) to authenticated, service_role;
grant execute on function public.submit_answer(bigint, integer, timestamptz) to authenticated, service_role;
grant execute on function public.complete_lesson(bigint, integer, timestamptz) to authenticated, service_role;
grant execute on function public.log_study_time(integer, timestamptz) to authenticated, service_role;

select 'B09 real dates ready' as result,
       has_function_privilege('authenticated', 'public.review_card(bigint,boolean,timestamptz)', 'execute') as students_can_review,
       has_function_privilege('anon', 'public.review_card(bigint,boolean,timestamptz)', 'execute') as anon_can_review,
       (select count(*) from pg_proc where proname in ('review_card','submit_answer','complete_lesson','log_study_time','_touch_activity')
          and pronamespace = 'public'::regnamespace) as functions_5;
