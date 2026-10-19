-- =============================================================================
-- KAMPUSLINK BACKEND  |  10  TESTS FOR FILE 09 (everything is rolled back)
-- =============================================================================
-- Same method as file 07: the block ends with an error on purpose, and the error text is
-- the report. "TEST RESULT (everything rolled back)" = it ran; read every line.
-- Lines starting with BAD, or a message starting with FAILED, need fixing: send them to me.
-- User: "walker Sky" (Mining, L2, university 6).
-- =============================================================================
do $$
declare
  uid   uuid := '322af894-2767-4a2c-8b1f-03a83b0590d0';
  res   text[] := '{}';
  step  text := 'start';
  mid   bigint; lid bigint; c1 bigint;
  r     jsonb;  r2 jsonb; n integer; v real; txt text;
  m1    uuid;   m2 uuid;
  op1   uuid := gen_random_uuid();
  op2   uuid := gen_random_uuid();
  op3   uuid := gen_random_uuid();
  cl    uuid := gen_random_uuid();
begin
  begin
    step := 'claims + module';
    perform set_config('request.jwt.claims',
      json_build_object('sub', uid, 'role', 'authenticated', 'email', 'test@example.com')::text, true);
    select t.id into mid from public.my_module_ids() as t(id) order by t.id limit 1;
    if mid is null then raise exception 'this user has no modules'; end if;

    ---------------------------------------------------------------- publish gate (as owner)
    step := 'publish gate';
    begin
      insert into public.learn_lessons (module_id, position, source_lang, status)
      values (mid, 90, 'fr', 'published');                       -- rights_status stays 'unknown'
      res := array_append(res, 'BAD: a lesson with unknown rights was published'::text);
    exception when others then
      res := array_append(res, format('ok: publish blocked when rights unknown (%s)', sqlerrm));
    end;
    begin
      insert into public.learn_lessons (module_id, position, source_lang, status, rights_status, needs_review)
      values (mid, 91, 'fr', 'published', 'own_work', true);
      res := array_append(res, 'BAD: a lesson that needs review was published'::text);
    exception when others then
      res := array_append(res, format('ok: publish blocked when review is pending (%s)', sqlerrm));
    end;

    ---------------------------------------------------------------- sample lesson with blocks
    step := 'insert sample lesson';
    insert into public.learn_lessons (module_id, position, source_lang, status, rights_status,
                                      chapter_ref, unit_number, unit_title, estimated_minutes, source_pages)
    values (mid, 1, 'fr', 'published', 'own_work',
            'chapter_02', 2, '{"en":"Oxygen and oxides","fr":"L''oxygène et les oxydes","ar":"الأكسجين والأكاسيد"}'::jsonb,
            6, '1-2')
    returning id into lid;
    insert into public.learn_lesson_i18n (lesson_id, lang, title, summary, blocks) values
      (lid, 'fr', 'Oxygène', 'Résumé',
       '[{"id":"sec_I_2_004","type":"paragraph","content":"Exceptions : F₂O et F₂O₂.","highlights":[{"text":"F₂O","kind":"formula"}]},
         {"id":"sec_I_2a_002","type":"chemical_reaction","formula":{"latex":"\\mathrm{O} + 2\\,\\mathrm{e}^{-} \\longrightarrow \\mathrm{O}^{2-}","plain_text":"O + 2 e⁻ → O²⁻"}}]'::jsonb),
      (lid, 'ar', 'الأكسجين', 'ملخص',
       '[{"id":"sec_I_2_004","type":"paragraph","content":"استثناءات: F₂O و F₂O₂.","highlights":[]}]'::jsonb),
      (lid, 'en', 'Oxygen', 'Summary',
       '[{"id":"sec_I_2_004","type":"paragraph","content":"Exceptions: F₂O and F₂O₂.","highlights":[]}]'::jsonb);
    insert into public.learn_cards (lesson_id, position) values (lid, 1) returning id into c1;
    insert into public.learn_card_i18n (card_id, lang, front, back) values
      (c1, 'fr', 'Q', 'R'), (c1, 'ar', 'س', 'ج'), (c1, 'en', 'Q', 'A');
    insert into public.module_glossary (module_id, fr, ar, en, definition)
    values (mid, 'oxygène', 'الأكسجين', 'oxygen', '{"fr":"gaz","ar":"غاز","en":"gas"}'::jsonb);

    set local role authenticated;

    ---------------------------------------------------------------- language-sliced bundle
    step := 'bundle with languages';
    r := public.get_module_bundle(mid, array['fr']);
    res := array_append(res, format('bundle[fr]: languages=%s | lesson i18n keys=%s | blocks=%s | unit title keys=%s | glossary def keys=%s',
      r ->> 'languages',
      (select string_agg(k, ',') from jsonb_object_keys(r -> 'lessons' -> 0 -> 'i18n') k),
      jsonb_array_length(r -> 'lessons' -> 0 -> 'i18n' -> 'fr' -> 'blocks'),
      (select string_agg(k, ',') from jsonb_object_keys(r -> 'lessons' -> 0 -> 'unit' -> 'title') k),
      (select string_agg(k, ',') from jsonb_object_keys(r -> 'glossary' -> 0 -> 'definition') k)));
    res := array_append(res, format('   expect: languages=["fr"], i18n keys=fr, blocks=2, unit title=fr, glossary def=fr | card i18n keys=%s',
      (select string_agg(k, ',') from jsonb_object_keys(r -> 'lessons' -> 0 -> 'cards' -> 0 -> 'i18n') k)));

    r2 := public.get_module_bundle(mid);
    res := array_append(res, format('bundle[all]: lesson i18n keys=%s | size %s chars vs %s chars for fr only',
      (select string_agg(k, ',' order by k) from jsonb_object_keys(r2 -> 'lessons' -> 0 -> 'i18n') k),
      length(r2::text), length(r::text)));

    begin
      perform public.get_module_bundle(mid, array['xx']);
      res := array_append(res, 'BAD: an unknown language was accepted'::text);
    exception when others then
      res := array_append(res, format('ok: unknown language rejected (%s)', sqlerrm));
    end;

    ---------------------------------------------------------------- reading position
    step := 'reading position';
    perform public.save_reading_position(lid, 'sec_I_2_004', 0.4);
    select count(*) into n from public.get_continue_items(5);
    select g.progress into v from public.get_continue_items(5) g where g.lesson_id = lid;
    res := array_append(res, format('continue items: %s, progress %s (expect 1 and 0.4)', n, v));

    perform public.save_reading_position(lid, 'sec_I_1_001', 0.1, now() - interval '1 hour');
    select g.progress into v from public.get_continue_items(5) g where g.lesson_id = lid;
    res := array_append(res, format('after an OLDER write, progress is still %s (expect 0.4: latest wins)', v));

    ---------------------------------------------------------------- offline sync
    step := 'sync_progress';
    r := public.sync_progress(jsonb_build_array(
      jsonb_build_object('op_id', op1, 'kind', 'study_time',       'payload', jsonb_build_object('seconds', 120)),
      jsonb_build_object('op_id', op2, 'kind', 'reading_position', 'payload',
        jsonb_build_object('lesson_id', lid, 'block_id', 'sec_I_2a_002', 'progress', 0.6, 'at', now())),
      jsonb_build_object('op_id', op3, 'kind', 'review',           'payload',
        jsonb_build_object('card_id', c1, 'correct', true)),
      jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'unknown_thing', 'payload', '{}'::jsonb)));
    res := array_append(res, format('sync first run -> %s', r::text));
    res := array_append(res, '   expect: 3 x applied + 1 x rejected (unknown_kind)'::text);

    r := public.sync_progress(jsonb_build_array(
      jsonb_build_object('op_id', op1, 'kind', 'study_time', 'payload', jsonb_build_object('seconds', 120)),
      jsonb_build_object('op_id', op3, 'kind', 'review', 'payload', jsonb_build_object('card_id', c1, 'correct', true))));
    res := array_append(res, format('sync replay -> %s (expect 2 x duplicate: nothing counted twice)', r::text));

    select g.progress into v from public.get_continue_items(5) g where g.lesson_id = lid;
    res := array_append(res, format('progress after sync: %s (expect 0.6)', v));
    r := public.get_me();
    res := array_append(res, format('today_seconds after sync: %s (expect 120)', r ->> 'today_seconds'));

    ---------------------------------------------------------------- chat idempotency
    step := 'chat client_id';
    r  := public.post_chat_message(mid, 'hello', 'en', null, null, cl);
    r2 := public.post_chat_message(mid, 'hello', 'en', null, null, cl);
    res := array_append(res, format('first send duplicate=%s, retry duplicate=%s, same message id: %s (expect false, true, true)',
      r ->> 'duplicate', r2 ->> 'duplicate', (r ->> 'message_id') = (r2 ->> 'message_id')));
    reset role;
    select count(*) into n from public.module_chat_messages where user_id = uid and client_id = cl;
    res := array_append(res, format('rows stored for that client_id: %s (expect 1)', n));

    ---------------------------------------------------------------- security
    step := 'security';
    set local role anon;
    begin
      perform public.sync_progress('[]'::jsonb);
      res := array_append(res, 'BAD: anon can call sync_progress'::text);
    exception when others then
      res := array_append(res, 'ok: anon cannot call sync_progress'::text);
    end;
    reset role;
  exception when others then
    raise exception 'FAILED at step "%": %', step, sqlerrm;
  end;

  raise exception E'TEST RESULT (everything rolled back):\n%', array_to_string(res, E'\n');
end $$;
