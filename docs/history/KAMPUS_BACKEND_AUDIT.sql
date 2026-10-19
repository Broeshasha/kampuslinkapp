-- =============================================================================
-- KAMPUSLINK BACKEND AUDIT  (READ-ONLY)
-- =============================================================================
-- HOW TO USE
--   1. Supabase Dashboard -> SQL Editor -> New query.
--   2. Paste ONE block (Q1, Q2, Q3, Q4) at a time and press Run.
--      The editor only shows the result of the last statement, so one block per run.
--   3. Each block returns ONE cell of JSON. Click the cell, copy it, paste it back to me.
--
-- SAFETY
--   * Every query only READS. Nothing here creates, changes or deletes anything.
--   * No emails, names, phone numbers or message text are selected. Only structure,
--     counts, and URL "shapes" (ids are masked).
--   * BEFORE pasting results anywhere: if you see any long secret (a service_role key,
--     a JWT, a password, an API token) inside a function definition, replace it with XXX.
--   * NEVER paste your database password, service_role key or JWT secret.
-- =============================================================================


-- =============================================================================
-- Q1  STRUCTURE: tables, columns, constraints, indexes
-- =============================================================================
select jsonb_build_object(
  'tables', (
    select coalesce(jsonb_agg(x order by x->>'table'), '[]'::jsonb)
    from (
      select jsonb_build_object(
        'table', c.relname,
        'type', case c.relkind
                  when 'r' then 'table'
                  when 'p' then 'partitioned'
                  when 'v' then 'view'
                  when 'm' then 'matview'
                end,
        'columns', (
          select jsonb_agg(jsonb_build_object(
                   'name', a.attname,
                   'type', format_type(a.atttypid, a.atttypmod),
                   'not_null', a.attnotnull,
                   'default', pg_get_expr(d.adbin, d.adrelid)
                 ) order by a.attnum)
          from pg_attribute a
          left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
          where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
        )
      ) as x
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
    ) t
  ),
  'constraints', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'table', cl.relname,
             'name', co.conname,
             'type', case co.contype
                       when 'p' then 'primary_key'
                       when 'f' then 'foreign_key'
                       when 'u' then 'unique'
                       when 'c' then 'check'
                       else co.contype::text
                     end,
             'definition', pg_get_constraintdef(co.oid)
           ) order by cl.relname, co.conname), '[]'::jsonb)
    from pg_constraint co
    join pg_class cl on cl.oid = co.conrelid
    join pg_namespace n on n.oid = cl.relnamespace
    where n.nspname = 'public'
  ),
  'indexes', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'table', tablename, 'name', indexname, 'definition', indexdef
           ) order by tablename, indexname), '[]'::jsonb)
    from pg_indexes
    where schemaname = 'public'
  )
) as kampus_q1_structure;


-- =============================================================================
-- Q2  SECURITY: row level security, policies, who can touch what
--     (the app ships the anon key inside the APK, so this is the most important check)
-- =============================================================================
select jsonb_build_object(
  'rls', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'table', c.relname,
             'rls_enabled', c.relrowsecurity,
             'rls_forced', c.relforcerowsecurity
           ) order by c.relname), '[]'::jsonb)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
  ),
  'policies', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'table', tablename,
             'name', policyname,
             'command', cmd,
             'roles', roles,
             'permissive', permissive,
             'using', qual,
             'with_check', with_check
           ) order by tablename, policyname), '[]'::jsonb)
    from pg_policies
    where schemaname = 'public'
  ),
  'grants_to_api_roles', (
    select coalesce(jsonb_agg(g order by g->>'table', g->>'role'), '[]'::jsonb)
    from (
      select jsonb_build_object(
               'table', table_name,
               'role', grantee,
               'privileges', jsonb_agg(privilege_type order by privilege_type)
             ) as g
      from information_schema.role_table_grants
      where table_schema = 'public' and grantee in ('anon', 'authenticated')
      group by table_name, grantee
    ) s
  )
) as kampus_q2_security;


-- =============================================================================
-- Q3  LOGIC: functions / RPCs (with full source), triggers, views
--     This is where the hidden news pipeline, home feed and account deletion live.
-- =============================================================================
select jsonb_build_object(
  'functions', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'name', p.proname,
             'kind', case p.prokind when 'f' then 'function' when 'p' then 'procedure' else p.prokind::text end,
             'arguments', pg_get_function_arguments(p.oid),
             'returns', pg_get_function_result(p.oid),
             'language', l.lanname,
             'security_definer', p.prosecdef,
             'anon_can_execute', has_function_privilege('anon', p.oid, 'execute'),
             'authenticated_can_execute', has_function_privilege('authenticated', p.oid, 'execute'),
             'definition', pg_get_functiondef(p.oid)
           ) order by p.proname), '[]'::jsonb)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_language l on l.oid = p.prolang
    where n.nspname = 'public'
      and p.prokind in ('f', 'p')
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  ),
  'triggers', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'schema', n.nspname,
             'table', c.relname,
             'name', t.tgname,
             'enabled', t.tgenabled,
             'definition', pg_get_triggerdef(t.oid)
           ) order by n.nspname, c.relname, t.tgname), '[]'::jsonb)
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where not t.tgisinternal
      and (n.nspname = 'public' or (n.nspname = 'auth' and c.relname = 'users'))
  ),
  'views', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'view', viewname, 'definition', definition
           ) order by viewname), '[]'::jsonb)
    from pg_views
    where schemaname = 'public'
  )
) as kampus_q3_logic;


-- =============================================================================
-- Q4  DATA AND STORAGE: row counts, where files really live (R2 vs Supabase),
--     auth provider counts, realtime tables, extensions
--     (needed BEFORE the R2 wipe: it shows which URL folders each table points to)
-- =============================================================================
select jsonb_build_object(
  'row_counts', (
    select coalesce(jsonb_object_agg(table_name, cnt order by table_name), '{}'::jsonb)
    from (
      select table_name,
             (xpath('/row/c/text()',
                    query_to_xml(format('select count(*) as c from %I.%I', table_schema, table_name),
                                 false, true, '')))[1]::text::bigint as cnt
      from information_schema.tables
      where table_schema = 'public' and table_type = 'BASE TABLE'
    ) s
  ),
  'file_url_folders', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'source', source,
             'host', host,
             'folder', folder,
             'files', n,
             'path_shape_example', example
           ) order by source, n desc), '[]'::jsonb)
    from (
      select source, m[2] as host, m[3] as folder, count(*) as n,
             min(regexp_replace(m[1], '[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}', '<uuid>', 'g')) as example
      from (
        select 'profiles.avatar_url' as source, m
        from public.profiles p
        cross join lateral regexp_matches(p.avatar_url::text,
             '((https?://[^/"\s,]+)/([^/"\s,]+)/[^"\s,}]*)', 'g') as m
        union all
        select 'community_posts.image_url', m
        from public.community_posts p
        cross join lateral regexp_matches(p.image_url::text,
             '((https?://[^/"\s,]+)/([^/"\s,]+)/[^"\s,}]*)', 'g') as m
        union all
        select 'marketplace_listings.image_urls', m
        from public.marketplace_listings p
        cross join lateral regexp_matches(p.image_urls::text,
             '((https?://[^/"\s,]+)/([^/"\s,]+)/[^"\s,}]*)', 'g') as m
        union all
        select 'study_resources.file_urls', m
        from public.study_resources p
        cross join lateral regexp_matches(p.file_urls::text,
             '((https?://[^/"\s,]+)/([^/"\s,]+)/[^"\s,}]*)', 'g') as m
      ) u
      group by source, m[2], m[3]
    ) g
  ),
  'supabase_storage_buckets', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'bucket', b.id,
             'public', b.public,
             'objects', (select count(*) from storage.objects o where o.bucket_id = b.id)
           ) order by b.id), '[]'::jsonb)
    from storage.buckets b
  ),
  'auth', jsonb_build_object(
    'users_total', (select count(*) from auth.users),
    'by_provider', (
      select coalesce(jsonb_object_agg(coalesce(p, 'none'), n), '{}'::jsonb)
      from (
        select raw_app_meta_data->>'provider' as p, count(*) as n
        from auth.users
        group by 1
      ) a
    )
  ),
  'realtime_tables', (
    select coalesce(jsonb_agg(schemaname || '.' || tablename order by tablename), '[]'::jsonb)
    from pg_publication_tables
    where pubname = 'supabase_realtime'
  ),
  'extensions', (
    select coalesce(jsonb_agg(extname order by extname), '[]'::jsonb)
    from pg_extension
  )
) as kampus_q4_data_and_storage;


-- =============================================================================
-- Q5  OPTIONAL: scheduled jobs (only if the "Cron" integration is enabled)
--     If it errors with: relation "cron.job" does not exist -> skip it.
--     WARNING: job commands sometimes contain keys in headers. Replace with XXX first.
-- =============================================================================
-- select jsonb_agg(jsonb_build_object(
--          'name', jobname, 'schedule', schedule, 'active', active, 'command', command
--        ) order by jobname) as kampus_q5_cron
-- from cron.job;


-- =============================================================================
-- NOT AVAILABLE FROM SQL (get these from the dashboard / CLI instead)
--   * Edge Functions list ........ Dashboard -> Edge Functions  (or: supabase functions list)
--   * Auth providers & redirects .. Dashboard -> Authentication -> Providers / URL Configuration
--   * Cloudflare Workers .......... Cloudflare -> Workers: upload.kampus-link.com and the
--                                   order-submit worker. I need their source code too
--                                   (the app calls them; their code is not in the app repo).
--   * R2 buckets .................. Cloudflare -> R2: bucket names, and top-level folder list.
-- =============================================================================
