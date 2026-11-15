-- KAMPUSLINK FILE 61: MOT-2 (MOTIVATION_DESIGN.md) - bac countdown settings, readiness weights,
-- week freeze (shop item, 200 XP, max 2 held, used automatically on a missed week).
-- Safe to run twice. Touches: app_config (new keys), kl_shop_items (kind list + 1 row),
-- kl_user_streak (+1 column), new table kl_week_freeze_used, buy_item / get_wallet (patched in place
-- from the live text - the script stops if the live text is not the expected one), new RPC use_week_freeze.
-- Kampus Store: not touched.

-- 1) Settings (change any time in the SQL editor, no app release):
--    bac_date            exam start, Algiers time. PROVISIONAL until the Ministry publishes it.
--    bac_date_confirmed  false = the app shows "about N weeks", true = the exact day count.
--    bac_subjects        per stream: readiness bars and their coefficients. Modules in one entry = one bar,
--                        every chapter inside counts the same.
insert into public.app_config (key, value) values
  ('bac_date', '"2027-06-13T08:30:00+01:00"'::jsonb),
  ('bac_date_confirmed', 'false'::jsonb),
  ('bac_subjects', '{"se":[{"key":"svt","modules":[3001],"coef":6},
                           {"key":"math","modules":[3004],"coef":5},
                           {"key":"phys","modules":[3002,3003],"coef":5}]}'::jsonb),
  ('week_goal_days', '5'::jsonb),
  ('shop_max_week_freezes', '2'::jsonb)
on conflict (key) do nothing;

-- 2) Week freeze item.
do $$
declare c text;
begin
  select conname into c from pg_constraint
   where conrelid = 'public.kl_shop_items'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%streak_freeze%';
  if c is not null and not exists (select 1 from pg_constraint where conname = c and pg_get_constraintdef(oid) like '%week_freeze%') then
    execute format('alter table public.kl_shop_items drop constraint %I', c);
    alter table public.kl_shop_items add constraint kl_shop_items_kind_check
      check (kind in ('streak_freeze','theme','card_skin','frame','title','pack','header_text','helper','celebration','streak_repair','week_freeze'));
  end if;
end $$;

insert into public.kl_shop_items (id, kind, price, name_i18n, desc_i18n, payload, sort) values
  ('week_freeze', 'week_freeze', 200,
   '{"en":"Week freeze","fr":"Gel de semaine","ar":"تجميد الأسبوع"}',
   '{"en":"Keeps your weeks in a row if you miss your weekly goal once. Used automatically.","fr":"Garde tes semaines d''affilée si tu rates ton objectif une fois. Utilisé automatiquement.","ar":"يحافظ على أسابيعك المتتالية إذا فاتك هدف الأسبوع مرة. يُستعمل تلقائيًا."}',
   '{}', 11)
on conflict (id) do nothing;

alter table public.kl_user_streak add column if not exists week_freezes int not null default 0;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'kl_user_streak_week_freezes_check') then
    alter table public.kl_user_streak add constraint kl_user_streak_week_freezes_check check (week_freezes >= 0);
  end if;
end $$;

create table if not exists public.kl_week_freeze_used (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  week_start date not null,                    -- Monday of the missed week
  used_at    timestamptz not null default now(),
  primary key (user_id, week_start)
);
alter table public.kl_week_freeze_used enable row level security;
drop policy if exists "week freeze own read" on public.kl_week_freeze_used;
create policy "week freeze own read" on public.kl_week_freeze_used for select to authenticated using (user_id = auth.uid());

-- 3) buy_item: the week_freeze kind (patched into the live function text).
do $$
declare d text; a1 text; a2 text;
begin
  d := pg_get_functiondef('public.buy_item(text)'::regprocedure);
  if position('week_freeze' in d) > 0 then return; end if;     -- already patched
  a1 := E'  bal := public._xp_balance(uid);\n';
  a2 := E'  if it.kind = ''streak_freeze'' then\n    update public.kl_user_streak set freezes = freezes + 1';
  if position(a1 in d) = 0 or position(a2 in d) = 0 then raise exception 'buy_item live text changed - stop, ask the engineer'; end if;
  d := replace(d, a1, E'  if it.kind = ''week_freeze'' then\n'
    || E'    insert into public.kl_user_streak (user_id) values (uid) on conflict do nothing;\n'
    || E'    select u.week_freezes into fz from public.kl_user_streak u where u.user_id = uid for update;\n'
    || E'    if fz >= public._cfg_int(''shop_max_week_freezes'', 2) then raise exception ''freeze_limit''; end if;\n'
    || E'  end if;\n' || a1);
  d := replace(d, a2, E'  if it.kind = ''week_freeze'' then\n'
    || E'    update public.kl_user_streak set week_freezes = week_freezes + 1, updated_at = now() where user_id = uid returning week_freezes into fz;\n'
    || E'  elsif it.kind = ''streak_freeze'' then\n    update public.kl_user_streak set freezes = freezes + 1');
  execute d;
end $$;

-- 4) get_wallet: + week_freezes, max_week_freezes, frozen_weeks (Mondays, newest first, last 60).
do $$
declare d text; a text := E'''header_text'', hdr);';
begin
  d := pg_get_functiondef('public.get_wallet()'::regprocedure);
  if position('week_freezes' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception 'get_wallet live text changed - stop, ask the engineer'; end if;
  d := replace(d, a, E'''header_text'', hdr,\n'
    || E'                            ''week_freezes'', coalesce((select u.week_freezes from public.kl_user_streak u where u.user_id = uid), 0),\n'
    || E'                            ''max_week_freezes'', public._cfg_int(''shop_max_week_freezes'', 2),\n'
    || E'                            ''frozen_weeks'', coalesce((select jsonb_agg(w.week_start order by w.week_start desc) from (select f.week_start from public.kl_week_freeze_used f where f.user_id = uid order by f.week_start desc limit 60) w), ''[]''::jsonb));');
  execute d;
end $$;

-- 5) use_week_freeze(p_week): the phone saw that LAST week (Monday p_week) missed the goal.
--    Only last week can be frozen; same week twice = no second freeze (idempotent).
create or replace function public.use_week_freeze(p_week date)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  uid uuid := auth.uid(); last_monday date; fz int; used boolean := false;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  last_monday := (date_trunc('week', public.algiers_today()::timestamp)::date) - 7;
  if p_week is distinct from last_monday then raise exception 'bad_week'; end if;
  perform pg_advisory_xact_lock(hashtextextended('klxp:' || uid::text, 0));
  if exists (select 1 from public.kl_week_freeze_used f where f.user_id = uid and f.week_start = p_week) then
    used := true;
  else
    select u.week_freezes into fz from public.kl_user_streak u where u.user_id = uid for update;
    if coalesce(fz, 0) > 0 then
      update public.kl_user_streak set week_freezes = week_freezes - 1, updated_at = now() where user_id = uid;
      insert into public.kl_week_freeze_used (user_id, week_start) values (uid, p_week);
      used := true;
    end if;
  end if;
  return jsonb_build_object('used', used,
    'week_freezes', coalesce((select u.week_freezes from public.kl_user_streak u where u.user_id = uid), 0));
end
$function$;
revoke all on function public.use_week_freeze(date) from public, anon;
grant execute on function public.use_week_freeze(date) to authenticated;
