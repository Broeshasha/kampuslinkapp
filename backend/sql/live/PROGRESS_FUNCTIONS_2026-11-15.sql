-- READ-ONLY COPY of the live progress functions (15 Nov 2026, before file 59). Reference only: do NOT run.
-- ### _apply_app_open(p_uid uuid, pl jsonb)
CREATE OR REPLACE FUNCTION public._apply_app_open(p_uid uuid, pl jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare at timestamptz := coalesce(nullif(pl ->> 'at', '')::timestamptz, now()); r public.user_reminder_state;
        cfg jsonb := coalesce((select value from public.app_config where key = 'reminder_second_chance'), '{"after_days":7,"for_days":2}');
begin
  select * into r from public.user_reminder_state where user_id = p_uid for update;
  if not found or not r.stopped or r.unsubscribed or r.second_chance_used then return; end if;
  if at < coalesce(r.stopped_at, r.prefs_updated_at) + make_interval(days => (cfg ->> 'after_days')::int) then return; end if;
  update public.user_reminder_state
     set stopped = false, after_pause = false, paused_until = null, declines_in_row = 0,
         second_chance_until = at + make_interval(days => (cfg ->> 'for_days')::int), second_chance_used = true, prefs_updated_at = now()
   where user_id = p_uid;
end
$function$


-- ### _apply_case_progress(p_uid uuid, pl jsonb)
CREATE OR REPLACE FUNCTION public._apply_case_progress(p_uid uuid, pl jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare sid bigint := (pl ->> 'set_id')::bigint; mid bigint;
begin
  select s.module_id into mid from public.learn_card_sets s where s.id = sid and s.status = 'published';
  if mid is null or not public.user_in_module(mid) then raise exception 'set_not_available'; end if;
  insert into public.learn_set_progress (user_id, set_id, reached, guess, correct, completed, updated_at)
  values (p_uid, sid, greatest(0, least(coalesce((pl ->> 'reached')::int, 0), 20)),
          nullif(pl ->> 'guess', '')::smallint, nullif(pl ->> 'correct', '')::boolean,
          coalesce((pl ->> 'completed')::boolean, false), coalesce(nullif(pl ->> 'at', '')::timestamptz, now()))
  on conflict (user_id, set_id) do update
    set reached   = greatest(public.learn_set_progress.reached, excluded.reached),
        guess     = coalesce(public.learn_set_progress.guess, excluded.guess),
        correct   = coalesce(public.learn_set_progress.correct, excluded.correct),
        completed = public.learn_set_progress.completed or excluded.completed,
        updated_at = greatest(public.learn_set_progress.updated_at, excluded.updated_at);
end $function$


-- ### _apply_content_report(p_uid uuid, pl jsonb)
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
end $function$


-- ### _apply_exam_attempt(p_uid uuid, pl jsonb)
CREATE OR REPLACE FUNCTION public._apply_exam_attempt(p_uid uuid, pl jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  aid  uuid;
  pid  bigint := nullif(pl ->> 'paper_id', '')::bigint;
  mid  bigint; ex jsonb; tp numeric;
  st   text := coalesce(nullif(pl ->> 'status', ''), 'in_progress');
  at   timestamptz := coalesce(nullif(pl ->> 'at', '')::timestamptz, now());
  sc   jsonb; tot numeric;
begin
  begin aid := (pl ->> 'attempt_id')::uuid; exception when others then raise exception 'invalid_attempt'; end;
  if aid is null then raise exception 'invalid_attempt'; end if;
  if st not in ('in_progress','finished','abandoned') then raise exception 'invalid_attempt'; end if;
  select x.module_id, x.exercises, x.total_points into mid, ex, tp
    from public.learn_exam_papers x where x.id = pid and x.status = 'published' and not x.hidden;
  if mid is null or not public.user_in_module(mid) then raise exception 'exam_not_available'; end if;
  if exists (select 1 from public.learn_exam_attempts a where a.id = aid and (a.user_id <> p_uid or a.paper_id <> pid)) then
    raise exception 'invalid_attempt';
  end if;
  -- keep only known parts, numbers only, clamp to 0..max of that part
  select coalesce(jsonb_object_agg(pp.part_key, least(greatest((s.value #>> '{}')::numeric, 0), pp.points)), '{}'::jsonb),
         coalesce(sum(least(greatest((s.value #>> '{}')::numeric, 0), pp.points)), 0)
    into sc, tot
    from jsonb_each(case when jsonb_typeof(pl -> 'scores') = 'object' then pl -> 'scores' else '{}'::jsonb end) s
    join public._exam_part_points(ex) pp on pp.part_key = s.key
   where jsonb_typeof(s.value) = 'number';
  tot := least(tot, tp);

  insert into public.learn_exam_attempts (id, user_id, paper_id, status, started_at, finished_at, scores, total, max_total, score_20, updated_at)
  values (aid, p_uid, pid, st, coalesce(nullif(pl ->> 'started_at', '')::timestamptz, at),
          case when st = 'finished' then coalesce(nullif(pl ->> 'finished_at', '')::timestamptz, at) end,
          sc, tot, tp, round(tot * 20 / tp, 2), at)
  on conflict (id) do update set
    status      = case when public.learn_exam_attempts.status = 'finished' then 'finished' else excluded.status end,
    finished_at = coalesce(public.learn_exam_attempts.finished_at, excluded.finished_at),
    scores      = case when excluded.updated_at >= public.learn_exam_attempts.updated_at then excluded.scores else public.learn_exam_attempts.scores end,
    total       = case when excluded.updated_at >= public.learn_exam_attempts.updated_at then excluded.total  else public.learn_exam_attempts.total  end,
    score_20    = case when excluded.updated_at >= public.learn_exam_attempts.updated_at then excluded.score_20 else public.learn_exam_attempts.score_20 end,
    max_total   = excluded.max_total,
    updated_at  = greatest(public.learn_exam_attempts.updated_at, excluded.updated_at);
end $function$


-- ### _apply_helper_use(p_uid uuid, pl jsonb)
CREATE OR REPLACE FUNCTION public._apply_helper_use(p_uid uuid, pl jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.kl_user_helpers set uses = uses - 1
   where user_id = p_uid and helper = pl ->> 'helper' and uses > 0;
  if not found then raise exception 'no_helper'; end if;
end
$function$


-- ### _apply_practice_progress(p_uid uuid, pl jsonb)
CREATE OR REPLACE FUNCTION public._apply_practice_progress(p_uid uuid, pl jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pid bigint := nullif(pl ->> 'practice_id', '')::bigint; mid bigint; r text := nullif(pl ->> 'self_rating', '');
begin
  select x.module_id into mid from public.learn_practice x where x.id = pid and x.status = 'published';
  if mid is null or not public.user_in_module(mid) then raise exception 'practice_not_available'; end if;
  if r is not null and r not in ('got_it','partly','missed') then raise exception 'invalid_rating'; end if;
  insert into public.learn_practice_progress (user_id, practice_id, hints_seen, solution_seen, self_rating, updated_at)
  values (p_uid, pid, greatest(0, least(coalesce(nullif(pl ->> 'hints_seen', '')::int, 0), 10)),
          coalesce(nullif(pl ->> 'solution_seen', '')::boolean, false), r,
          coalesce(nullif(pl ->> 'at', '')::timestamptz, now()))
  on conflict (user_id, practice_id) do update set
    hints_seen    = greatest(public.learn_practice_progress.hints_seen, excluded.hints_seen),
    solution_seen = public.learn_practice_progress.solution_seen or excluded.solution_seen,
    self_rating   = coalesce(excluded.self_rating, public.learn_practice_progress.self_rating),
    updated_at    = greatest(public.learn_practice_progress.updated_at, excluded.updated_at);
end $function$


-- ### _apply_reminder_response(p_uid uuid, pl jsonb)
CREATE OR REPLACE FUNCTION public._apply_reminder_response(p_uid uuid, pl jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare resp text := pl ->> 'response'; at timestamptz := coalesce(nullif(pl ->> 'at', '')::timestamptz, now());
        r public.user_reminder_state;
begin
  if resp not in ('started', 'not_now', 'ignored') then raise exception 'invalid_response'; end if;
  insert into public.user_reminder_state (user_id) values (p_uid) on conflict (user_id) do nothing;
  select * into r from public.user_reminder_state where user_id = p_uid for update;
  if r.stopped or r.unsubscribed then return; end if;
  if resp = 'started' then
    update public.user_reminder_state set declines_in_row = 0, after_pause = false, paused_until = null, second_chance_until = null,
           prefs_updated_at = now() where user_id = p_uid;
  elsif r.second_chance_until is not null then                    -- inside the second chance: 2 declines -> stopped for good
    if r.declines_in_row + 1 >= 2 then
      update public.user_reminder_state set stopped = true, stopped_at = now(), declines_in_row = 0, second_chance_until = null,
             second_chance_used = true, prefs_updated_at = now() where user_id = p_uid;
    else
      update public.user_reminder_state set declines_in_row = r.declines_in_row + 1, prefs_updated_at = now() where user_id = p_uid;
    end if;
  elsif r.paused_until is not null and at < r.paused_until then
    return;
  elsif r.after_pause then
    update public.user_reminder_state set stopped = true, stopped_at = now(), declines_in_row = 0, paused_until = null,
           prefs_updated_at = now() where user_id = p_uid;
  elsif r.declines_in_row + 1 >= 2 then
    update public.user_reminder_state set declines_in_row = 0, paused_until = at + interval '3 days', after_pause = true,
           prefs_updated_at = now() where user_id = p_uid;
  else
    update public.user_reminder_state set declines_in_row = r.declines_in_row + 1, prefs_updated_at = now() where user_id = p_uid;
  end if;
end
$function$


-- ### _apply_story_answer(p_uid uuid, p_op uuid, pl jsonb)
CREATE OR REPLACE FUNCTION public._apply_story_answer(p_uid uuid, p_op uuid, pl jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  return 0;
end
$function$


-- ### _apply_story_view(p_uid uuid, pl jsonb)
CREATE OR REPLACE FUNCTION public._apply_story_view(p_uid uuid, pl jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  null;
end
$function$


-- ### _coins_after_op(p_uid uuid, p_op uuid, p_kind text, pl jsonb)
CREATE OR REPLACE FUNCTION public._coins_after_op(p_uid uuid, p_op uuid, p_kind text, pl jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare today date := public.algiers_today(); pid bigint; sc numeric; st public.study_stats;
begin
  begin
    if p_kind = 'exam_attempt' then
      select a.paper_id, a.score_20 into pid, sc from public.learn_exam_attempts a
       where a.id = (pl ->> 'attempt_id')::uuid and a.user_id = p_uid and a.status = 'finished' and a.total > 0;
      if pid is not null then
        perform public._note_achievement(p_uid, 'exam', 'attempt:' || (pl ->> 'attempt_id'),
                                         jsonb_build_object('paper_id', pid, 'score_20', sc));
      end if;
    end if;
    if p_kind not in ('app_open', 'reading_position', 'story_view') then
      select * into st from public.study_stats where user_id = p_uid;
      if st.last_active_date = today and exists (
           select 1 from jsonb_array_elements_text(coalesce((select c.value from public.app_config c where c.key = 'achievement_streaks'), '[]'::jsonb)) e
            where e.value ~ '^[0-9]+$' and e.value::int = st.current_streak) then
        perform public._note_achievement(p_uid, 'streak', 'streak:' || st.current_streak || ':' || (today - (st.current_streak - 1))::text,
                                         jsonb_build_object('days', st.current_streak));
      end if;
    end if;
  exception when others then
    raise warning 'after-op hook skipped: %', sqlerrm;
  end;
  return 0;
end
$function$


-- ### _streak_state(p_uid uuid)
CREATE OR REPLACE FUNCTION public._streak_state(p_uid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$


-- ### _touch_activity(p_user uuid, p_xp integer)
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
$function$


-- ### complete_lesson(p_lesson bigint, p_score integer)
CREATE OR REPLACE FUNCTION public.complete_lesson(p_lesson bigint, p_score integer DEFAULT NULL::integer)
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
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into les from public.learn_lessons where id = p_lesson and status = 'published';
  if les.id is null or not public.user_in_module(les.module_id) then
    raise exception 'not_available';
  end if;

  first_time := not exists (select 1 from public.learn_lesson_progress
                             where user_id = uid and lesson_id = p_lesson);
  insert into public.learn_lesson_progress (user_id, lesson_id, score)
  values (uid, p_lesson, p_score)
  on conflict (user_id, lesson_id) do update
    set score = greatest(coalesce(public.learn_lesson_progress.score, 0), coalesce(excluded.score, 0));

  perform public._touch_activity(uid, case when first_time then 10 else 1 end);

  select l.id into nxt from public.learn_lessons l
   where l.module_id = les.module_id and l.status = 'published'
     and (l.position, l.id) > (les.position, les.id)
   order by l.position, l.id limit 1;
  return jsonb_build_object('first_time', first_time, 'next_lesson_id', nxt);
end $function$


-- ### get_me()
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
$function$


-- ### log_study_time(p_seconds integer)
CREATE OR REPLACE FUNCTION public.log_study_time(p_seconds integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid   uuid := auth.uid();
  s     integer := least(greatest(coalesce(p_seconds, 0), 0), 900);
  today date := public.algiers_today();
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
    if total >= 300 then perform public._touch_activity(uid, 0); end if;   -- 5 active minutes = streak day
  else
    select d.active_seconds into total from public.study_daily d where d.user_id = uid and d.day = today;
  end if;
  total := coalesce(total, 0);
  return jsonb_build_object('today_seconds', total, 'goal_seconds', goal, 'goal_reached', total >= goal);
end $function$


-- ### review_card(p_card bigint, p_correct boolean)
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
end $function$


-- ### submit_answer(p_question bigint, p_choice integer)
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
   where a.user_id = uid and a.question_id = q.id and a.created_at >= v_since;

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
end $function$


-- ### sync_progress(p_ops jsonb)
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
        perform public.review_card((v_pl ->> 'card_id')::bigint, (v_pl ->> 'correct')::boolean);
      elsif v_kind = 'answer' then
        perform public.submit_answer((v_pl ->> 'question_id')::bigint, (v_pl ->> 'choice')::integer);
      elsif v_kind = 'lesson_done' then
        perform public.complete_lesson((v_pl ->> 'lesson_id')::bigint, nullif(v_pl ->> 'score', '')::integer);
      elsif v_kind = 'study_time' then
        perform public.log_study_time((v_pl ->> 'seconds')::integer);
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
end $function$


-- ### zz_columns client_ops
user_id uuid nullable=NO default=-
op_id uuid nullable=NO default=-
kind text nullable=NO default=-
status text nullable=NO default='applied'::text
message text nullable=YES default=-
created_at timestamp with time zone nullable=NO default=now()

-- ### zz_columns kl_user_streak
user_id uuid nullable=NO default=-
freezes integer nullable=NO default=0
last_freeze_on date nullable=YES default=-
last_freeze_days integer nullable=YES default=-
updated_at timestamp with time zone nullable=NO default=now()
last_repair_on date nullable=YES default=-

-- ### zz_columns learn_card_progress
user_id uuid nullable=NO default=-
card_id bigint nullable=NO default=-
box integer nullable=NO default=1
due_at timestamp with time zone nullable=NO default=now()
last_reviewed_at timestamp with time zone nullable=YES default=-
reps integer nullable=NO default=0
lapses integer nullable=NO default=0

-- ### zz_columns learn_lesson_progress
user_id uuid nullable=NO default=-
lesson_id bigint nullable=NO default=-
completed_at timestamp with time zone nullable=NO default=now()
score integer nullable=YES default=-

-- ### zz_columns learn_quiz_attempts
id uuid nullable=NO default=gen_random_uuid()
user_id uuid nullable=NO default=-
lesson_id bigint nullable=NO default=-
question_id bigint nullable=NO default=-
chosen_index integer nullable=NO default=-
is_correct boolean nullable=NO default=-
created_at timestamp with time zone nullable=NO default=now()

-- ### zz_columns study_daily
user_id uuid nullable=NO default=-
day date nullable=NO default=-
active_seconds integer nullable=NO default=0
cards_reviewed integer nullable=NO default=0
xp integer nullable=NO default=0

-- ### zz_columns study_stats
user_id uuid nullable=NO default=-
xp integer nullable=NO default=0
current_streak integer nullable=NO default=0
longest_streak integer nullable=NO default=0
last_active_date date nullable=YES default=-