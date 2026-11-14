-- 52_BAC1_YEAR_CHECK.sql - BAC-1 follow-up: CHECK constraints on year columns must accept '3AS'.
-- (profiles_academic_year_check refused it.) Existing allowed values are kept. Safe to re-run.
do $y$
declare r record; v_col text;
begin
  for r in select c.conname, c.conrelid::regclass::text as tbl, pg_get_constraintdef(c.oid) as def
             from pg_constraint c
            where c.contype = 'c' and c.connamespace = 'public'::regnamespace
              and c.conrelid in ('public.profiles'::regclass, 'public.kl_waitlist'::regclass,
                                 'public.study_modules'::regclass, 'public.kl_offers'::regclass)
              and pg_get_constraintdef(c.oid) ~ '\m(academic_year|year|bac_year)\M'
              and pg_get_constraintdef(c.oid) ~ '= ANY \(ARRAY\['
              and pg_get_constraintdef(c.oid) !~ '''3AS''' loop
    v_col := substring(r.def from '\(+\s*([a-z_]+)\s*= ANY');
    -- keep the original rule exactly, only add "or <col> = '3AS'"
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
    execute format('alter table %s add constraint %I check ((%s) or %I = %L)', r.tbl, r.conname,
                   regexp_replace(r.def, '^CHECK ', ''), v_col, '3AS');
    raise notice 'year check % on % now allows 3AS', r.conname, r.tbl;
  end loop;
end $y$;

select conrelid::regclass as tbl, conname, pg_get_constraintdef(oid) as def
  from pg_constraint where contype = 'c' and connamespace = 'public'::regnamespace
   and pg_get_constraintdef(oid) ~ '3AS';
