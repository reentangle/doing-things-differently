-- Run once in your new Supabase project's SQL Editor, as postgres.
-- This transaction exposes only a tightly scoped, write-only function.
begin;

create table public.responses (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  x numeric(5,2) not null check (x between 0 and 100),
  y numeric(5,2) not null check (y between 0 and 100),
  job text not null check (char_length(btrim(job)) between 1 and 160)
);
create index responses_created_at_idx on public.responses (created_at);

alter table public.responses enable row level security;
-- No RLS policies: default deny for every ordinary caller.
-- Also remove direct API access, including automatic Supabase grants.
revoke all on table public.responses from public, anon, authenticated;
revoke all on sequence public.responses_id_seq from public, anon, authenticated;

create function public.submit_response(
  p_x numeric,
  p_y numeric,
  p_job text,
  p_website text default ''
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_x is null or p_y is null or
     not (p_x between 0 and 100) or not (p_y between 0 and 100) or
     p_job is null or char_length(btrim(p_job)) not between 1 and 160 or
     coalesce(p_website, '') <> '' then
    raise exception 'Invalid submission.';
  end if;

  -- A server-side, experiment-wide ceiling. The lock prevents concurrent
  -- requests from exceeding the limit. It does not identify visitors.
  if not pg_catalog.pg_try_advisory_xact_lock(714093821::bigint) then
    raise exception 'Too many submissions. Please try again in a minute.';
  end if;
  if (select count(*) from public.responses
      where created_at >= pg_catalog.clock_timestamp() - interval '1 minute') >= 60 then
    raise exception 'Too many submissions. Please try again in a minute.';
  end if;

  insert into public.responses (x, y, job) values (p_x, p_y, btrim(p_job));
end;
$$;

-- Functions otherwise inherit EXECUTE for PUBLIC by default.
revoke all on function public.submit_response(numeric, numeric, text, text)
  from public, anon, authenticated;
grant usage on schema public to anon;
grant execute on function public.submit_response(numeric, numeric, text, text) to anon;

commit;
