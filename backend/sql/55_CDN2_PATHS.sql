-- =====================================================================
-- 55_CDN2_PATHS.sql  (FIX_PLAN 3.1 / CDN-2, server part). Safe to re-run. Old apps: nothing changes.
-- 1) app_config 'cdn_percent' (0-100, starts at 0 = CDN off for everyone). The SERVER decides who is in the
--    rollout (stable per student), so the phone needs no flag logic:
--      update public.app_config set value = '5'  where key = 'cdn_percent';   -- 5 % of students
--      update public.app_config set value = '100' where key = 'cdn_percent';  -- everyone
--      update public.app_config set value = '0'  where key = 'cdn_percent';   -- kill switch
-- 2) get_my_cdn_paths(): {"<module id>": "<manifest path>"} for the student's modules, ONLY when the published
--    CDN copy is the current version (cdn_version = version). Empty when the student is outside the rollout.
-- 3) app_open() also returns it as "cdn" (no extra call). Fix: the catalog hash no longer includes
--    generated_at (it changed every call, so the catalog was re-sent at every app open).
-- 4) get_module_resources(module): the library list alone (the CDN files do not carry it).
-- =====================================================================
insert into public.app_config (key, value) values ('cdn_percent', '0'::jsonb) on conflict (key) do nothing;

create or replace function public.get_my_cdn_paths()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case
    when auth.uid() is null then '{}'::jsonb
    when (hashtext(auth.uid()::text)::bigint & 2147483647) % 100
         >= coalesce((select case when (c.value #>> '{}') ~ '^[0-9]{1,3}$' then (c.value #>> '{}')::int end
                        from public.app_config c where c.key = 'cdn_percent'), 0)
      then '{}'::jsonb
    else coalesce((
      select jsonb_object_agg(v.module_id::text, v.cdn_path)
        from public.module_content_versions v
       where v.cdn_path is not null and v.cdn_version = v.version
         and v.module_id in (select public.my_module_ids())), '{}'::jsonb)
  end
$$;
revoke all on function public.get_my_cdn_paths() from public, anon;
grant execute on function public.get_my_cdn_paths() to authenticated, service_role;

create or replace function public.get_module_resources(p_module bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.user_in_module(p_module) then raise exception 'not_in_module'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id, 'type', r.resource_type, 'format', r.file_format, 'title', r.title,
      'file_urls', r.file_urls, 'trust_label', r.trust_label, 'size_bytes', r.size_bytes,
      'origin', r.origin, 'created_at', r.created_at) order by r.created_at desc)
    from public.study_resources r where r.module_id = p_module and r.status = 'visible'), '[]'::jsonb);
end $$;
revoke all on function public.get_module_resources(bigint) from public, anon;
grant execute on function public.get_module_resources(bigint) to authenticated, service_role;

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
  v_hash := md5(coalesce((v_cat - 'generated_at')::text, ''));
  return jsonb_build_object(
    'me',           to_jsonb(public.get_me()),
    'wallet',       to_jsonb(public.get_wallet()),
    'catalog',      case when v_hash is distinct from p_catalog_hash then v_cat end,
    'catalog_hash', v_hash,
    'cdn',          public.get_my_cdn_paths()
  );
end $$;
revoke all on function public.app_open(text) from public, anon;
grant execute on function public.app_open(text) to authenticated, service_role;

select 'CDN-2 ready' as result,
       (select value from public.app_config where key = 'cdn_percent') as cdn_percent,
       has_function_privilege('authenticated', 'public.get_my_cdn_paths()', 'execute') as students_can_run,
       has_function_privilege('anon', 'public.get_my_cdn_paths()', 'execute') as anon_can_run,
       (select count(*) from public.module_content_versions where cdn_path is not null and cdn_version = version) as modules_on_cdn;
