-- Run in Supabase SQL Editor after submitting through the website.
-- These queries are for you (the project owner), never the public website.
select id, created_at, x, y, job
from public.responses
order by created_at desc, id desc
limit 20;

-- Expected: true, false, false, false, false, true, false.
select
  (select relrowsecurity from pg_class where oid = 'public.responses'::regclass) as rls_enabled,
  has_table_privilege('anon', 'public.responses', 'SELECT') as anon_can_read,
  has_table_privilege('anon', 'public.responses', 'INSERT') as anon_can_insert_directly,
  has_table_privilege('anon', 'public.responses', 'UPDATE') as anon_can_update,
  has_table_privilege('anon', 'public.responses', 'DELETE') as anon_can_delete,
  has_function_privilege('anon', 'public.submit_response(numeric,numeric,text,text)', 'EXECUTE') as anon_can_submit,
  has_function_privilege('authenticated', 'public.submit_response(numeric,numeric,text,text)', 'EXECUTE') as authenticated_can_submit;
