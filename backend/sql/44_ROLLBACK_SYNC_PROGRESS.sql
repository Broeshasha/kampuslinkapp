-- 44_ROLLBACK_SYNC_PROGRESS.sql: the sync_progress body BEFORE file 44 (copied from production 14 Nov 2026).
-- Run only to undo step 1 of 44.
CREATE OR REPLACE FUNCTION public.sync_progress(p_ops jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  uid     uuid := auth.uid();
  item    jsonb;
  v_id    uuid;
  v_kind  text;
  v_pl    jsonb;
  v_card  bigint;
  v_st    text;
  v_msg   text;
  v_coins integer := 0;
  results jsonb := '[]'::jsonb;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_ops is null or jsonb_typeof(p_ops) <> 'array' then raise exception 'invalid_ops'; end if;
  if jsonb_array_length(p_ops) > 200 then raise exception 'too_many_ops'; end if;

  for item in select e.value from jsonb_array_elements(p_ops) e loop
    begin
      v_id := (item ->> 'op_id')::uuid;
    exception when others then
      results := results || jsonb_build_object('op_id', item ->> 'op_id', 'status', 'rejected', 'message', 'invalid_op_id');
      continue;
    end;
    v_kind := item ->> 'kind';
    v_coins := 0;
    v_pl   := coalesce(item -> 'payload', '{}'::jsonb);

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
        if not exists (select 1 from public.learn_cards c
                         join public.learn_lessons l on l.id = c.lesson_id
                        where c.id = v_card and l.status = 'published' and public.user_in_module(l.module_id)) then
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
      v_coins := v_coins + public._coins_after_op(uid, v_id, v_kind, v_pl);
      v_st := 'applied'; v_msg := null;
    exception when others then
      v_st := 'rejected'; v_msg := sqlerrm;
    end;

    insert into public.client_ops (user_id, op_id, kind, status, message)
    values (uid, v_id, left(coalesce(v_kind, '?'), 30), v_st, left(v_msg, 200));
    results := results || jsonb_build_object('op_id', v_id, 'status', v_st, 'message', v_msg, 'coins', case when v_st = 'applied' then v_coins else 0 end);
  end loop;
  return results;
end $function$;
