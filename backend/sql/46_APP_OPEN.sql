-- =====================================================================
-- 46_APP_OPEN.sql - ONE call when the app opens (founder request, B04 follow-up).
-- app_open(p_catalog_hash) = get_me + get_wallet + get_my_catalog in one round trip.
-- The catalog is sent only when it changed (the phone sends the hash it has).
-- Old apps keep calling the three functions: nothing removed. Safe to re-run.
-- =====================================================================
create or replace function public.app_open(p_catalog_hash text default null)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_cat  jsonb;
  v_hash text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  v_cat  := to_jsonb(public.get_my_catalog());
  v_hash := md5(coalesce(v_cat::text, ''));
  return jsonb_build_object(
    'me',           to_jsonb(public.get_me()),
    'wallet',       to_jsonb(public.get_wallet()),
    'catalog',      case when v_hash is distinct from p_catalog_hash then v_cat end,
    'catalog_hash', v_hash
  );
end $$;

revoke all on function public.app_open(text) from public, anon;
grant execute on function public.app_open(text) to authenticated, service_role;

select 'app_open ready' as result, has_function_privilege('authenticated', 'public.app_open(text)', 'execute') as authenticated_can_run,
       has_function_privilege('anon', 'public.app_open(text)', 'execute') as anon_can_run;
