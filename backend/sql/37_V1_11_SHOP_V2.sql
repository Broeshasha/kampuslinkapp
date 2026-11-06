-- KAMPUSLINK FILE 37: shop v2. Card skins, celebrations, study helpers (practice only), streak repair, a custom
-- header name (own phone + own share images only), and EARNED items that cannot be bought (30-day streak, exam ace,
-- ambassador). Run ONCE after file 35, then file 38 (test, rolls back).

-- =============================================================================
-- PART 1  SCHEMA
-- =============================================================================
do $k37$
declare c text;
begin
  select conname into c from pg_constraint
   where conrelid = 'public.kl_shop_items'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%streak_freeze%';
  if c is not null then execute format('alter table public.kl_shop_items drop constraint %I', c); end if;
  alter table public.kl_shop_items add constraint kl_shop_items_kind_check
    check (kind in ('streak_freeze','theme','card_skin','frame','title','pack','header_text','helper','celebration','streak_repair'));
end
$k37$;
alter table public.kl_shop_items add column if not exists buyable boolean not null default true;
alter table public.kl_shop_items add column if not exists unlock jsonb;            -- how an earned item is won, e.g. {"streak":30}
alter table public.kl_user_streak add column if not exists last_repair_on date;

create table if not exists public.kl_user_helpers (
  user_id uuid not null references public.profiles(id) on delete cascade,
  helper  text not null check (helper in ('fifty_fifty','hint')),
  uses    int  not null default 0 check (uses >= 0),
  primary key (user_id, helper)
);
create table if not exists public.kl_user_extras (
  user_id     uuid primary key references public.profiles(id) on delete cascade,
  header_text text,
  updated_at  timestamptz not null default now()
);
create table if not exists public.kl_blocked_words (                -- add rows any time (lowercase); checked as "contains"
  word text primary key check (word = lower(word) and length(word) >= 2)
);
do $s37$
declare t text;
begin
  foreach t in array array['kl_user_helpers','kl_user_extras','kl_blocked_words'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke insert, update, delete, truncate on public.%I from authenticated', t);
  end loop;
end
$s37$;

insert into public.app_config (key, value) values
  ('streak_repair_cooldown_days', '30'::jsonb),
  ('header_text_max', '20'::jsonb)
on conflict (key) do nothing;

-- =============================================================================
-- PART 2  ITEMS
-- =============================================================================
insert into public.kl_shop_items (id, kind, price, name_i18n, desc_i18n, payload, sort, buyable, unlock) values
  ('skin_paper','card_skin',500,'{"en":"Paper cards","fr":"Cartes papier","ar":"بطاقات ورقية"}','{"en":"Warm paper look for every flashcard.","fr":"Un look papier chaleureux pour chaque carte.","ar":"مظهر ورقي دافئ لكل بطاقة."}','{"bg":["#FFF8E7","#F3E5C0"],"fg":"#2B2B2B"}',70,true,null),
  ('skin_night','card_skin',500,'{"en":"Night cards","fr":"Cartes nuit","ar":"بطاقات ليلية"}','{"en":"Deep blue cards, easy on the eyes.","fr":"Cartes bleu nuit, reposantes.","ar":"بطاقات زرقاء داكنة مريحة للعين."}','{"bg":["#141E30","#243B55"],"fg":"#FFFFFF"}',71,true,null),
  ('skin_mint','card_skin',500,'{"en":"Mint cards","fr":"Cartes menthe","ar":"بطاقات نعناعية"}','{"en":"Fresh green cards.","fr":"Des cartes vertes et fraîches.","ar":"بطاقات خضراء منعشة."}','{"bg":["#E6FCF5","#96F2D7"],"fg":"#0B3D2E"}',72,true,null),
  ('skin_sunset','card_skin',800,'{"en":"Sunset cards","fr":"Cartes coucher de soleil","ar":"بطاقات الغروب"}','{"en":"Orange to pink, every card.","fr":"De l’orange au rose, sur chaque carte.","ar":"من البرتقالي إلى الوردي في كل بطاقة."}','{"bg":["#FF922B","#F06595"],"fg":"#FFFFFF"}',73,true,null),
  ('fx_confetti','celebration',300,'{"en":"Confetti","fr":"Confettis","ar":"قصاصات ملونة"}','{"en":"Confetti when you get it right.","fr":"Des confettis quand tu as juste.","ar":"قصاصات ملونة عند الإجابة الصحيحة."}','{"style":"confetti"}',80,true,null),
  ('fx_stars','celebration',300,'{"en":"Stars","fr":"Étoiles","ar":"نجوم"}','{"en":"A burst of stars when you get it right.","fr":"Une pluie d’étoiles quand tu as juste.","ar":"نجوم تتطاير عند الإجابة الصحيحة."}','{"style":"stars"}',81,true,null),
  ('fx_fireworks','celebration',700,'{"en":"Fireworks","fr":"Feu d’artifice","ar":"ألعاب نارية"}','{"en":"Fireworks for every right answer.","fr":"Un feu d’artifice à chaque bonne réponse.","ar":"ألعاب نارية لكل إجابة صحيحة."}','{"style":"fireworks"}',82,true,null),
  ('pack_5050','helper',120,'{"en":"50/50 × 5","fr":"50/50 × 5","ar":"50/50 × 5"}','{"en":"Removes two wrong answers in practice (never in mock exams).","fr":"Retire deux mauvaises réponses en entraînement (jamais en examen blanc).","ar":"يحذف إجابتين خاطئتين في التمارين (أبداً في الامتحانات التجريبية)."}','{"helper":"fifty_fifty","uses":5}',20,true,null),
  ('pack_hint','helper',120,'{"en":"Hints × 5","fr":"Indices × 5","ar":"تلميحات × 5"}','{"en":"One extra hint in practice (never in mock exams).","fr":"Un indice en plus en entraînement (jamais en examen blanc).","ar":"تلميح إضافي في التمارين (أبداً في الامتحانات التجريبية)."}','{"helper":"hint","uses":5}',21,true,null),
  ('streak_repair','streak_repair',500,'{"en":"Streak repair","fr":"Réparer ma série","ar":"إصلاح السلسلة"}','{"en":"Missed yesterday with no freeze? Get your streak back. Once a month.","fr":"Raté hier sans gel ? Récupère ta série. Une fois par mois.","ar":"فاتك الأمس دون تجميد؟ استرجع سلسلتك. مرة في الشهر."}','{}',11,true,null),
  ('custom_header','header_text',3000,'{"en":"Your name on top","fr":"Ton nom en haut","ar":"اسمك في الأعلى"}','{"en":"Write your own text instead of KampusLink on your Home screen and your share images.","fr":"Écris ton propre texte à la place de KampusLink sur ton accueil et tes images partagées.","ar":"اكتب نصك الخاص بدل KampusLink في شاشتك الرئيسية وصور المشاركة."}','{}',5,true,null),
  ('frame_streak_30','frame',0,'{"en":"Legend frame","fr":"Cadre légende","ar":"إطار الأسطورة"}','{"en":"Earned with a 30-day streak.","fr":"Gagné avec 30 jours d’affilée.","ar":"يُكسب بسلسلة 30 يوماً."}','{"colors":["#FF6B6B","#845EF7"]}',90,false,'{"streak":30}'),
  ('title_streak_30','title',0,'{"en":"30-day legend","fr":"Légende des 30 jours","ar":"أسطورة الثلاثين يوماً"}','{"en":"Earned with a 30-day streak.","fr":"Gagné avec 30 jours d’affilée.","ar":"يُكسب بسلسلة 30 يوماً."}','{}',91,false,'{"streak":30}'),
  ('title_exam_ace','title',0,'{"en":"Exam ace","fr":"As des examens","ar":"بطل الامتحانات"}','{"en":"Earned with 18/20 or more on a mock exam.","fr":"Gagné avec 18/20 ou plus à un examen blanc.","ar":"يُكسب بـ 18/20 أو أكثر في امتحان تجريبي."}','{}',92,false,'{"exam_20":18}'),
  ('frame_ambassador','frame',0,'{"en":"Ambassador frame","fr":"Cadre ambassadeur","ar":"إطار السفير"}','{"en":"Earned when 3 friends you invited study 3 days.","fr":"Gagné quand 3 amis invités étudient 3 jours.","ar":"يُكسب عندما يدرس 3 أصدقاء دعوتهم لمدة 3 أيام."}','{"colors":["#20C997","#FAB005"]}',93,false,'{"invites":3}')
on conflict (id) do nothing;

-- =============================================================================
-- PART 3  EARNED ITEMS: granted by the server when the achievement is recorded
-- =============================================================================
create or replace function public._note_achievement(p_uid uuid, p_kind text, p_ref text, p_payload jsonb)
returns void language plpgsql security definer set search_path = public as $f$
declare it record;
begin
  insert into public.kl_achievements (user_id, kind, ref, payload) values (p_uid, p_kind, p_ref, p_payload)
  on conflict (user_id, kind, ref) do nothing;
  for it in select s.id, s.unlock from public.kl_shop_items s where s.active and not s.buyable and s.unlock is not null loop
    if (p_kind = 'streak' and it.unlock ? 'streak' and coalesce((p_payload ->> 'days')::int, 0) >= (it.unlock ->> 'streak')::int)
       or (p_kind = 'exam' and it.unlock ? 'exam_20' and coalesce((p_payload ->> 'score_20')::numeric, 0) >= (it.unlock ->> 'exam_20')::numeric) then
      insert into public.kl_user_inventory (user_id, item_id) values (p_uid, it.id) on conflict do nothing;
    end if;
  end loop;
end
$f$;

-- =============================================================================
-- PART 4  BUY v2 (helpers stack, streak repair, earned items not for sale), HEADER TEXT, HELPER USE
-- =============================================================================
create or replace function public.buy_item(p_item text)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare
  uid uuid := auth.uid(); it public.kl_shop_items; bal int; fz int; today date := public.algiers_today(); st public.study_stats; lr date;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(hashtextextended('klcoin:' || uid::text, 0));
  select * into it from public.kl_shop_items where id = p_item;
  if it.id is null then raise exception 'item_not_found'; end if;
  if not it.active then raise exception 'item_inactive'; end if;
  if not it.buyable then raise exception 'not_for_sale'; end if;
  if it.kind = 'streak_freeze' then
    insert into public.kl_user_streak (user_id) values (uid) on conflict do nothing;
    select u.freezes into fz from public.kl_user_streak u where u.user_id = uid for update;
    if fz >= public._cfg_int('coins_max_freezes', 2) then raise exception 'freeze_limit'; end if;
  elsif it.kind = 'streak_repair' then
    select * into st from public.study_stats where user_id = uid for update;
    if st.user_id is null or st.last_active_date is distinct from today - 2 or coalesce(st.current_streak, 0) < 1 then
      raise exception 'nothing_to_repair';
    end if;
    select u.last_repair_on into lr from public.kl_user_streak u where u.user_id = uid;
    if lr is not null and lr > today - public._cfg_int('streak_repair_cooldown_days', 30) then raise exception 'repair_cooldown'; end if;
  elsif it.kind <> 'helper' and exists (select 1 from public.kl_user_inventory i where i.user_id = uid and i.item_id = it.id) then
    raise exception 'already_owned';
  end if;
  select coalesce(sum(l.amount), 0) into bal from public.kl_coin_ledger l where l.user_id = uid;
  if bal < it.price then raise exception 'insufficient_coins'; end if;
  if it.price > 0 then
    insert into public.kl_coin_ledger (user_id, amount, reason, ref) values (uid, -it.price, 'shop_buy', 'buy:' || gen_random_uuid()::text);
  end if;
  if it.kind = 'streak_freeze' then
    update public.kl_user_streak set freezes = freezes + 1, updated_at = now() where user_id = uid returning freezes into fz;
  elsif it.kind = 'streak_repair' then
    update public.study_stats set last_active_date = today - 1 where user_id = uid;       -- yesterday counts again
    insert into public.kl_user_streak (user_id, last_repair_on) values (uid, today)
    on conflict (user_id) do update set last_repair_on = today, updated_at = now();
  elsif it.kind = 'helper' then
    insert into public.kl_user_helpers (user_id, helper, uses) values (uid, it.payload ->> 'helper', coalesce((it.payload ->> 'uses')::int, 1))
    on conflict (user_id, helper) do update set uses = public.kl_user_helpers.uses + excluded.uses;
  else
    insert into public.kl_user_inventory (user_id, item_id) values (uid, it.id);
  end if;
  return jsonb_build_object('item_id', it.id, 'balance', bal - it.price, 'freezes', fz);
end
$f$;

create or replace function public.set_header_text(p_text text)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare uid uuid := auth.uid(); t text := btrim(regexp_replace(coalesce(p_text, ''), '\s+', ' ', 'g'));
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.kl_user_inventory i where i.user_id = uid and i.item_id = 'custom_header') then raise exception 'not_owned'; end if;
  if t = '' then
    insert into public.kl_user_extras (user_id, header_text) values (uid, null)
    on conflict (user_id) do update set header_text = null, updated_at = now();
    return jsonb_build_object('header_text', null);
  end if;
  if length(t) < 2 or length(t) > public._cfg_int('header_text_max', 20)
     or t !~ '^[A-Za-z0-9\u00C0-\u017F\u0600-\u06FF\u0750-\u077F ._''!-]+$' then
    raise exception 'invalid_text';
  end if;
  if exists (select 1 from public.kl_blocked_words w where position(w.word in lower(t)) > 0) then raise exception 'blocked_text'; end if;
  insert into public.kl_user_extras (user_id, header_text) values (uid, t)
  on conflict (user_id) do update set header_text = excluded.header_text, updated_at = now();
  return jsonb_build_object('header_text', t);
end
$f$;

create or replace function public._apply_helper_use(p_uid uuid, pl jsonb)
returns void language plpgsql security definer set search_path = public as $f$
begin
  update public.kl_user_helpers set uses = uses - 1
   where user_id = p_uid and helper = pl ->> 'helper' and uses > 0;
  if not found then raise exception 'no_helper'; end if;
end
$f$;

do $p37$
declare fdef text; m text := E'      elsif v_kind in (''like'', ''save'') then';
begin
  select pg_get_functiondef(to_regprocedure('public.sync_progress(jsonb)')) into fdef;
  if position('helper_use' in fdef) > 0 then raise notice 'sync_progress already has helper_use'; return; end if;
  if (length(fdef) - length(replace(fdef, m, ''))) <> length(m) then raise exception 'sync_progress marker not unique: send it to the lead'; end if;
  fdef := replace(fdef, m, E'      elsif v_kind = ''helper_use'' then\n        perform public._apply_helper_use(uid, v_pl);\n' || m);
  execute fdef;
end
$p37$;

-- =============================================================================
-- PART 5  WALLET v2: + helpers, header text, equipped items with their look
-- =============================================================================
create or replace function public.get_wallet()
returns jsonb language plpgsql stable security definer set search_path = public as $f$
declare
  uid uuid := auth.uid(); today date := public.algiers_today(); bal int; earned int; cap int := public._cfg_int('coins_daily_cap', 100); inv jsonb; helpers jsonb; hdr text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select coalesce(sum(l.amount), 0) into bal from public.kl_coin_ledger l where l.user_id = uid;
  select coalesce(sum(l.amount), 0) into earned from public.kl_coin_ledger l
    join public.kl_coin_rules x on x.reason = l.reason and x.in_global_cap
   where l.user_id = uid and l.day = today and l.amount > 0;
  select coalesce(jsonb_agg(jsonb_build_object('item_id', i.item_id, 'kind', s.kind, 'equipped', i.equipped, 'payload', s.payload) order by i.acquired_at), '[]'::jsonb)
    into inv from public.kl_user_inventory i join public.kl_shop_items s on s.id = i.item_id where i.user_id = uid;
  select coalesce(jsonb_object_agg(h.helper, h.uses), '{}'::jsonb) into helpers from public.kl_user_helpers h where h.user_id = uid;
  select e.header_text into hdr from public.kl_user_extras e where e.user_id = uid;
  return jsonb_build_object('balance', bal, 'today_earned', earned, 'daily_cap', cap, 'cap_remaining', greatest(cap - earned, 0),
                            'max_freezes', public._cfg_int('coins_max_freezes', 2),
                            'streak', public._streak_state(uid), 'inventory', inv, 'helpers', helpers, 'header_text', hdr);
end
$f$;

do $g37$
declare f text;
begin
  foreach f in array array['public._apply_helper_use(uuid,jsonb)','public._note_achievement(uuid,text,text,jsonb)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array['public.buy_item(text)','public.set_header_text(text)','public.get_wallet()'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$g37$;
notify pgrst, 'reload schema';
