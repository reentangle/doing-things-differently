-- Counter matches the current shared map: consenting, active, unexpired responses
-- from the latest published questionnaire version. Historical responses remain unchanged.
create or replace function public.get_research_response_count()
returns bigint language sql stable security definer set search_path=''
as $function$
 select count(*) from public.responses
 where deleted_at is null
 and created_at >= pg_catalog.statement_timestamp()-interval '1 year'
 and share_position is true
 and questionnaire_version = (
   select version from public.research_copy_versions order by revision desc limit 1
 );
$function$;
