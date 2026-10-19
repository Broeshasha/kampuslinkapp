-- =============================================================================
-- KAMPUSLINK BACKEND  |  07  TEST AS A REAL USER (nothing is kept)
-- =============================================================================
-- HOW IT WORKS
--   Each block below is a DO block that:
--     1. pretends to be one of your users (sets the login claims and the 'authenticated' role)
--     2. creates sample lesson/cards/quiz inside the same transaction (as owner)
--     3. calls the real functions exactly like the app will
--     4. ENDS WITH AN ERROR ON PURPOSE, which rolls EVERYTHING back. The error message is
--        your test report. Do not be scared by the red box: it is the result.
--   "TEST RESULT (everything rolled back)" = the run worked; read each line.
--   Any line that starts with BAD, or a message starting with FAILED, needs fixing:
--   copy it to me.
--
-- USERS USED (from your C6 result)
--   Block A  322af894-2767-4a2c-8b1f-03a83b0590d0  "walker Sky"  Mining, university 6, L2
--   Block B/C 8051b847-763c-43c6-b139-13074adfa764  "test_user_8051b8" (empty profile)
-- Run the blocks one at a time, in order: A, B, C.
-- (Block A uses the column rights_status from file 09. Run 09 before re-running this file.)
-- =============================================================================


-- =============================================================================
-- BLOCK A  FULL STUDENT FLOW (modules, feed, review, quiz, social, chat, files, offline
--          bundle) + SECURITY CHECKS
-- =============================================================================
do $$
declare
  uid   uuid := '322af894-2767-4a2c-8b1f-03a83b0590d0';
  res   text[] := '{}';
  step  text := 'start';
  mid   bigint; lid bigint; c1 bigint; c2 bigint; qid bigint;
  r     jsonb;  m1 jsonb;   n integer; v integer; cid uuid;
  rid1  bigint; rid2 bigint; fbase text; tb text; ulang text;
begin
  begin
    ---------------------------------------------------------------- login as the user
    step := 'set login claims';
    perform set_config('request.jwt.claims',
      json_build_object('sub', uid, 'role', 'authenticated', 'email', 'test@example.com')::text, true);
    res := res || format('auth.uid() = %s', auth.uid());

    step := 'find the user''s modules';
    select count(*) into n from public.my_module_ids();
    select t.id into mid from public.my_module_ids() as t(id) order by t.id limit 1;
    if mid is null then
      raise exception 'this user has NO modules: check the profile (speciality, year, university) and study_modules (round-2 query R3)';
    end if;
    res := res || format('modules for this user: %s (using module id %s)', n, mid);

    ---------------------------------------------------------------- sample content (as owner)
    step := 'insert sample content';
    -- NOTE: after file 09 a lesson cannot be published with unknown rights, so the test says own_work
    insert into public.learn_lessons (module_id, position, source_lang, status, generated_by, rights_status)
      values (mid, 1, 'fr', 'published', 'test', 'own_work') returning id into lid;
    insert into public.learn_lesson_i18n (lesson_id, lang, title, summary, body_md) values
      (lid, 'fr', 'Leçon test', 'Résumé', '# Test'),
      (lid, 'ar', 'درس تجريبي', 'ملخص', '# تجربة');
    insert into public.learn_cards (lesson_id, position) values (lid, 1) returning id into c1;
    insert into public.learn_cards (lesson_id, position) values (lid, 2) returning id into c2;
    insert into public.learn_card_i18n (card_id, lang, front, back) values
      (c1, 'fr', 'Question 1', 'Réponse 1'), (c1, 'en', 'Question 1', 'Answer 1'),
      (c2, 'fr', 'Question 2', 'Réponse 2'), (c2, 'en', 'Question 2', 'Answer 2');
    insert into public.learn_questions (lesson_id, kind, correct_index, position)
      values (lid, 'mcq', 1, 1) returning id into qid;
    insert into public.learn_question_i18n (question_id, lang, prompt, options, explanation) values
      (qid, 'en', '2 + 2 ?', '["3","4","5"]'::jsonb, 'because'),
      (qid, 'fr', '2 + 2 ?', '["3","4","5"]'::jsonb, 'parce que');
    select version into v from public.module_content_versions where module_id = mid;
    res := res || format('content version bumped by the triggers: %s (expect 1 or more)', coalesce(v, 0));

    set local role authenticated;   -- from here on we act like the app

    ---------------------------------------------------------------- modules + feed
    step := 'get_me';
    r := public.get_me();
    ulang := r ->> 'language';
    res := res || format('get_me: %s | speciality %s | year %s | language %s',
                         r ->> 'username', r ->> 'speciality_name', r ->> 'academic_year', ulang);

    step := 'get_my_modules';
    select g.lessons into n from public.get_my_modules() g where g.module_id = mid;
    res := res || format('get_my_modules: lessons in the test module = %s (expect 1)', n);

    step := 'get_home_cards';
    select count(*) into n from public.get_home_cards(10);
    res := res || format('home cards: %s (expect 2: both new)', n);

    ---------------------------------------------------------------- review, social
    step := 'review_card';
    r := public.review_card(c1, true);
    res := res || format('review_card(correct) -> box %s (expect 2)', r ->> 'box');

    step := 'toggle_card_like';
    r := public.toggle_card_like(c1);
    res := res || format('like -> %s (expect liked true, count 1)', r::text);

    step := 'add_card_comment';
    cid := public.add_card_comment(c1, 'test comment');
    select count(*) into n from public.get_card_comments(c1);
    res := res || format('comments on the card: %s (expect 1)', n);

    ---------------------------------------------------------------- quiz
    step := 'submit_answer (wrong)';
    r := public.submit_answer(qid, 0);
    res := res || format('wrong answer -> %s (expect correct=false, correct_index=1)', r::text);
    select p.box into v from public.learn_card_progress p where p.card_id = c1 and p.user_id = uid;
    res := res || format('card 1 pulled back to box %s (expect 1)', v);

    step := 'submit_answer (right)';
    r := public.submit_answer(qid, 1);
    res := res || format('right answer -> %s (expect correct=true)', r::text);

    step := 'complete_lesson';
    r := public.complete_lesson(lid, 100);
    res := res || format('complete_lesson 1st -> %s (expect first_time=true)', r::text);
    r := public.complete_lesson(lid, 80);
    res := res || format('complete_lesson 2nd -> %s (expect first_time=false)', r::text);

    ---------------------------------------------------------------- study time + streak
    step := 'log_study_time';
    r  := public.log_study_time(400);
    m1 := public.get_me();
    res := res || format('log_study_time -> %s | streak %s | xp %s',
                         r::text, m1 ->> 'current_streak', m1 ->> 'xp');

    ---------------------------------------------------------------- chat + translation
    step := 'post_chat_message (arabic)';
    r := public.post_chat_message(mid, 'مرحبا test', 'ar');
    res := res || format('posted message %s', r ->> 'message_id');

    reset role;   -- the translation micro writes as the service: simulate it as owner
    insert into public.message_translations (message_id, lang, body, provider) values
      ((r ->> 'message_id')::uuid, 'en', 'hello test (EN translation)', 'test'),
      ((r ->> 'message_id')::uuid, 'fr', 'bonjour test (FR translation)', 'test');
    set local role authenticated;

    step := 'get_chat_messages';
    select count(*), max(g.translated_body) into n, tb from public.get_chat_messages(mid, null, 20) g;
    res := res || format('chat messages: %s | translated for language "%s": %s', n, ulang, coalesce(tb, '(none)'));

    ---------------------------------------------------------------- files shared in chat
    step := 'file in chat';
    select c.value #>> '{}' into fbase from public.app_config c where c.key = 'files_base_url';
    m1 := jsonb_build_object('url', fbase || 'files/test-' || mid || '.pdf', 'hash', 'testhash_' || mid,
                             'size', 12345, 'mime', 'application/pdf', 'title', 'TD test',
                             'type', 'td', 'format', 'pdf');
    r    := public.post_chat_message(mid, 'voici le TD', 'fr', null, m1);
    rid1 := (r ->> 'resource_id')::bigint;
    r    := public.post_chat_message(mid, 'même fichier', 'fr', null, m1);
    rid2 := (r ->> 'resource_id')::bigint;
    res := res || format('file resource ids: %s and %s (expect the SAME id)', rid1, rid2);
    select count(*) into n from public.study_resources
     where module_id = mid and file_hash = 'testhash_' || mid;
    res := res || format('Library rows for that file: %s (expect 1, readable by the student)', n);

    begin
      perform public.post_chat_message(mid, 'bad link', 'fr', null,
        jsonb_build_object('url', 'https://evil.example.com/x.pdf'));
      res := array_append(res, 'BAD: a foreign file link was accepted'::text);
    exception when others then
      res := res || format('ok: foreign file link rejected (%s)', sqlerrm);
    end;

    ---------------------------------------------------------------- the offline JSON
    step := 'get_module_bundle';
    r := public.get_module_bundle(mid);
    res := res || format('bundle: lessons=%s, cards in lesson 1=%s, questions=%s, library files=%s, version=%s',
      jsonb_array_length(r -> 'lessons'),
      jsonb_array_length(r -> 'lessons' -> 0 -> 'cards'),
      jsonb_array_length(r -> 'lessons' -> 0 -> 'questions'),
      jsonb_array_length(r -> 'resources'), r ->> 'version');
    res := res || format('bundle size: %s characters of JSON', length(r::text));

    ---------------------------------------------------------------- SECURITY (as the student)
    step := 'security checks';
    select count(*) into n from public.profiles where id <> uid;
    res := res || format('SECURITY other profile rows readable in the table: %s (expect 0)', n);

    select count(*) into n from public.public_profiles;
    res := res || format('public_profiles rows visible: %s (only students with the NEW onboarding)', n);

    begin
      insert into public.module_chat_messages (module_id, user_id, body) values (mid, uid, 'direct insert');
      res := array_append(res, 'BAD: a direct insert into module_chat_messages was allowed'::text);
    exception when others then res := array_append(res, 'ok: direct chat insert is blocked'::text);
    end;

    begin
      update public.study_stats set xp = 999999 where user_id = uid;
      get diagnostics n = row_count;
      if n > 0 then res := array_append(res, 'BAD: the student can edit their own xp directly'::text);
      else res := array_append(res, 'ok: direct xp update changes nothing'::text); end if;
    exception when others then res := array_append(res, 'ok: direct xp update is blocked'::text);
    end;

    begin
      update public.learn_card_progress set box = 5 where user_id = uid;
      get diagnostics n = row_count;
      if n > 0 then res := array_append(res, 'BAD: the student can edit card progress directly'::text);
      else res := array_append(res, 'ok: direct card progress update changes nothing'::text); end if;
    exception when others then res := array_append(res, 'ok: direct card progress update is blocked'::text);
    end;

    res := res || format('can anon call call_send_push? %s | can a student call it? %s (both expect false; if true run file 06 F1)',
      has_function_privilege('anon', 'public.call_send_push(jsonb)', 'execute'),
      has_function_privilege('authenticated', 'public.call_send_push(jsonb)', 'execute'));

    reset role;
    set local role anon;
    begin
      select count(*) into n from public.notifications;
      res := res || format('SECURITY anon sees %s notifications (expect 0)', n);
    exception when others then res := array_append(res, 'ok: anon cannot read notifications'::text);
    end;
    begin
      select count(*) into n from public.study_resources;
      res := res || format('BAD: anon can read the library (%s rows)', n);
    exception when others then res := array_append(res, 'ok: anon cannot read the library'::text);
    end;
    reset role;

  exception when others then
    raise exception 'FAILED at step "%": %', step, sqlerrm;
  end;

  raise exception E'TEST RESULT (everything rolled back):\n%', array_to_string(res, E'\n');
end $$;


-- =============================================================================
-- BLOCK B  ONBOARDING (the empty test profile). Tries bad inputs first, then a good one.
--          Uses university 6 and speciality 2 (Mining), year L2: change if you like.
-- =============================================================================
do $$
declare
  uid  uuid := '8051b847-763c-43c6-b139-13074adfa764';
  uni  integer := 6;
  res  text[] := '{}';
  step text := 'start';
  r    jsonb;
  n    integer;
begin
  begin
    step := 'set login claims';
    perform set_config('request.jwt.claims',
      json_build_object('sub', uid, 'role', 'authenticated', 'email', 'test@example.com')::text, true);
    set local role authenticated;

    step := 'get_onboarding_options';
    r := public.get_onboarding_options();
    res := res || format('options: %s universities, %s specialities',
                         jsonb_array_length(r -> 'universities'), jsonb_array_length(r -> 'specialities'));

    step := 'bad inputs';
    begin perform public.complete_onboarding('ab', uni, 2, 'L2');
      res := array_append(res, 'BAD: 2-letter username accepted'::text);
    exception when others then res := res || format('ok: short username rejected (%s)', sqlerrm); end;
    begin perform public.complete_onboarding('good_name', uni, 2, 'Year 9');
      res := array_append(res, 'BAD: impossible year accepted'::text);
    exception when others then res := res || format('ok: bad year rejected (%s)', sqlerrm); end;
    begin perform public.complete_onboarding('good_name', 99999, 2, 'L2');
      res := array_append(res, 'BAD: unknown university accepted'::text);
    exception when others then res := res || format('ok: unknown university rejected (%s)', sqlerrm); end;
    begin perform public.complete_onboarding('professor_mpofu', uni, 2, 'L2');
      res := array_append(res, 'BAD: a taken username was accepted'::text);
    exception when others then res := res || format('ok: taken username rejected (%s)', sqlerrm); end;

    step := 'good onboarding';
    r := public.complete_onboarding('test_user_01', uni, 2, 'L2', 'fr', 'A', 'G1');
    res := res || format('onboarding done -> username %s | onboarding_version %s | complete %s',
                         r ->> 'username', r ->> 'onboarding_version', r ->> 'onboarding_complete');
    select count(*) into n from public.my_module_ids();
    res := res || format('modules after onboarding: %s', n);

    step := 'settings';
    perform public.set_language('ar');
    perform public.set_reminders(false);
    perform public.register_push_token(repeat('x', 40), 'android');
    r := public.get_me();
    res := res || format('after settings -> language %s | reminders_enabled %s (expect ar / false)',
                         r ->> 'language', r ->> 'reminders_enabled');

    reset role;
    select count(*) into n from public.push_tokens where user_id = uid;
    res := res || format('push tokens stored for this user: %s (expect 1)', n);
  exception when others then
    raise exception 'FAILED at step "%": %', step, sqlerrm;
  end;

  raise exception E'TEST RESULT (everything rolled back):\n%', array_to_string(res, E'\n');
end $$;


-- =============================================================================
-- BLOCK C  ACCOUNT DELETION (store policy). Creates data for the test profile, deletes the
--          account, checks that nothing is left. Rolled back, so the profile survives.
-- =============================================================================
do $$
declare
  uid  uuid := '8051b847-763c-43c6-b139-13074adfa764';
  res  text[] := '{}';
  step text := 'start';
  n    integer;
begin
  begin
    step := 'set login claims';
    perform set_config('request.jwt.claims',
      json_build_object('sub', uid, 'role', 'authenticated', 'email', 'test@example.com')::text, true);

    step := 'create some data for this user';
    insert into public.study_stats (user_id) values (uid) on conflict (user_id) do nothing;
    insert into public.study_daily (user_id, day, active_seconds) values (uid, public.algiers_today(), 60)
      on conflict (user_id, day) do nothing;
    insert into public.push_tokens (token, user_id) values (repeat('d', 40), uid) on conflict do nothing;
    insert into public.user_reminder_state (user_id) values (uid) on conflict (user_id) do nothing;

    step := 'delete the account as the user';
    set local role authenticated;
    perform public.delete_my_account();
    reset role;

    select count(*) into n from public.profiles where id = uid;
    res := res || format('profile rows left: %s (expect 0)', n);
    select count(*) into n from auth.users where id = uid;
    res := res || format('login rows left: %s (expect 0)', n);
    select (select count(*) from public.study_daily where user_id = uid)
         + (select count(*) from public.push_tokens where user_id = uid)
         + (select count(*) from public.user_reminder_state where user_id = uid)
         + (select count(*) from public.study_stats where user_id = uid) into n;
    res := res || format('leftover rows in study_daily / push_tokens / reminders / stats: %s (expect 0)', n);
  exception when others then
    raise exception 'FAILED at step "%": %', step, sqlerrm;
  end;

  raise exception E'TEST RESULT (everything rolled back):\n%', array_to_string(res, E'\n');
end $$;
