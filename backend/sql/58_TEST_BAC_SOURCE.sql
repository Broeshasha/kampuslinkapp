-- 58_TEST_BAC_SOURCE.sql - run AFTER 57. Changes nothing (ends with an error on purpose).
-- Expected last line: "BAC SOURCE TEST: ALL 5 PASSED (rolled back on purpose)".
do $t$
declare v_uid uuid; v_mod bigint; v_les bigint; v_q bigint; v_c bigint; v_rev1 text; v_rev2 text; v_j jsonb; v_ok int := 0;
begin
  if (select count(*) from information_schema.columns where table_schema = 'public'
        and table_name in ('learn_cards','learn_questions','learn_practice') and column_name in ('source','based_on')) <> 6 then
    raise exception 'BAC SOURCE TEST T1 FAILED: columns missing'; end if;
  v_ok := v_ok + 1;
  -- a student + one of his modules with a published lesson that has a question and a card
  for v_uid in select p.id from public.profiles p
                where not coalesce(p.is_admin, false) and p.speciality_id is not null limit 200 loop
    perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    select l.module_id, l.id into v_mod, v_les
      from public.learn_lessons l
     where l.module_id in (select public.my_module_ids()) and l.status = 'published'
       and exists (select 1 from public.learn_questions q where q.lesson_id = l.id and not q.hidden)
       and exists (select 1 from public.learn_cards c where c.lesson_id = l.id and not c.hidden)
     limit 1;
    exit when v_les is not null;
  end loop;
  if v_les is null then raise exception 'BAC SOURCE TEST: no student lesson with cards + questions found'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  select id into v_q from public.learn_questions where lesson_id = v_les and not hidden order by position, id limit 1;
  select id into v_c from public.learn_cards where lesson_id = v_les and not hidden order by position, id limit 1;

  -- T2: no source yet = no key in the lesson JSON (old JSON unchanged)
  v_j := public._lesson_json(v_les, null);
  if exists (select 1 from jsonb_array_elements(v_j -> 'questions') e where e ? 'source' or e ? 'based_on')
     and not exists (select 1 from public.learn_questions where lesson_id = v_les and (source is not null or based_on is not null)) then
    raise exception 'BAC SOURCE TEST T2 FAILED: empty source sent'; end if;
  v_ok := v_ok + 1;

  set local role authenticated;
  select e ->> 'rev' into v_rev1 from jsonb_array_elements(public.get_module_manifest(v_mod, array['ar','en','fr']) -> 'lessons') e
   where (e ->> 'id')::bigint = v_les;
  reset role;

  update public.learn_questions set source = '{"type":"bac","year":2019,"session":"june","stream":"SE"}' where id = v_q;
  update public.learn_cards set based_on = '{"type":"bac","year":2018}' where id = v_c;

  -- T3: keys travel in the lesson JSON
  v_j := public._lesson_json(v_les, array['ar','en']);
  if not exists (select 1 from jsonb_array_elements(v_j -> 'questions') e where (e -> 'source' ->> 'year') = '2019') then
    raise exception 'BAC SOURCE TEST T3 FAILED: source missing'; end if;
  if not exists (select 1 from jsonb_array_elements(v_j -> 'cards') e where (e -> 'based_on' ->> 'year') = '2018') then
    raise exception 'BAC SOURCE TEST T3 FAILED: based_on missing'; end if;
  v_ok := v_ok + 1;

  -- T4: the lesson rev moves (phones download the change)
  set local role authenticated;
  select e ->> 'rev' into v_rev2 from jsonb_array_elements(public.get_module_manifest(v_mod, array['ar','en','fr']) -> 'lessons') e
   where (e ->> 'id')::bigint = v_les;
  reset role;
  if v_rev1 is null or v_rev1 = v_rev2 then raise exception 'BAC SOURCE TEST T4 FAILED: rev % -> %', v_rev1, v_rev2; end if;
  v_ok := v_ok + 1;

  -- T5: the CDN export carries it too
  if not exists (select 1 from jsonb_array_elements(public.cdn_module_export(v_mod) -> 'lessons') l,
                 jsonb_array_elements(l -> 'questions') q where (q -> 'source' ->> 'year') = '2019') then
    raise exception 'BAC SOURCE TEST T5 FAILED: CDN export without source'; end if;
  v_ok := v_ok + 1;
  raise exception 'BAC SOURCE TEST: ALL % PASSED (rolled back on purpose)', v_ok;
end $t$;
