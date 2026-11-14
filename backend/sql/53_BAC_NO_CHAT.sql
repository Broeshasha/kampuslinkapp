-- 53_BAC_NO_CHAT.sql - B16: chat and card comments are OFF for the bac track (minors), enforced on the
-- server (the app already hides them). A trigger refuses any new message/comment written by a bac
-- account, whatever function inserts it. Safe to re-run. Rollback: drop the two triggers.
create or replace function public._no_bac_posts() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_uid uuid;
begin
  v_uid := (to_jsonb(new) ->> tg_argv[0])::uuid;
  if exists (select 1 from public.profiles p where p.id = v_uid and p.track = 'bac') then
    raise exception 'forbidden';
  end if;
  return new;
end $$;
revoke all on function public._no_bac_posts() from public, anon, authenticated;

do $b$
declare v_tbl text; v_col text;
begin
  foreach v_tbl in array array['module_chat_messages', 'learn_card_comments'] loop
    if to_regclass('public.' || v_tbl) is null then continue; end if;
    select column_name into v_col from information_schema.columns
     where table_schema = 'public' and table_name = v_tbl
       and column_name in ('user_id', 'sender_id', 'author_id')
     order by array_position(array['user_id','sender_id','author_id'], column_name::text) limit 1;
    if v_col is null then raise exception 'B16: no author column on % - tell the engineer', v_tbl; end if;
    execute format('drop trigger if exists trg_no_bac_posts on public.%I', v_tbl);
    execute format('create trigger trg_no_bac_posts before insert on public.%I for each row execute function public._no_bac_posts(%L)',
                   v_tbl, v_col);
    raise notice 'bac block on %.%', v_tbl, v_col;
  end loop;
end $b$;

select tgrelid::regclass as table_name, tgname from pg_trigger where tgname = 'trg_no_bac_posts';
