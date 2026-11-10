begin;
CREATE OR REPLACE FUNCTION public.github_get_private_responses(p_reader_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY INVOKER
 SET search_path TO ''
AS $function$
begin
 -- Authentication is enforced by the service-role-only grant and the Edge session check.
 return (select coalesce(jsonb_agg(jsonb_build_object(
   'difference_dimensions_other',difference_dimensions_other,'situation',situation,'difference_dimensions',difference_dimensions,'work_country',work_country,'reference_code',reference_code,'id',id::text,'created_at',created_at,'x',x,'y',y,'job',job,
   'difference_reason',difference_reason,'financial_support',financial_support,
   'ends_meet',ends_meet,'support_other',support_other,'share_position',share_position,'share_job',share_job,'sharing_notice_version',sharing_notice_version,'consent_recorded_at',consent_recorded_at,'questionnaire_version',questionnaire_version
 ) order by id desc),'[]'::jsonb) from public.responses
 where deleted_at is null and created_at >= pg_catalog.statement_timestamp()-interval '1 year');
end; $function$
;
revoke all on function public.github_get_private_responses(text) from public,anon,authenticated;
grant execute on function public.github_get_private_responses(text) to service_role;
CREATE OR REPLACE FUNCTION public.github_save_research_content(p_reader_token text, p_expected_revision bigint, p_texts jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
declare current_copy public.research_copy_versions%rowtype; new_revision bigint; item record;
begin
 -- Authentication is enforced by the service-role-only grant and the Edge session check.
 perform pg_catalog.pg_advisory_xact_lock(714093822::bigint);
 select * into current_copy from public.research_copy_versions order by revision desc limit 1;
 if p_expected_revision is distinct from current_copy.revision then return jsonb_build_object('error','conflict'); end if;
 if p_texts is null or jsonb_typeof(p_texts)<>'object' or pg_catalog.octet_length(p_texts::text)>200000 then raise exception 'Invalid text.'; end if;
 if (select array_agg(key order by key) from jsonb_object_keys(p_texts) as key) is distinct from
    (select array_agg(key order by key) from jsonb_object_keys(current_copy.texts) as key) then raise exception 'Invalid text fields.'; end if;
 for item in select key,value from jsonb_each(p_texts) loop
  if jsonb_typeof(item.value)<>'string' or char_length(btrim(item.value #>> '{}'))=0 or char_length(item.value #>> '{}')>5000 then raise exception 'Invalid text.'; end if;
 end loop;
 insert into public.research_copy_versions(version,texts) values('pending-'||pg_catalog.gen_random_uuid()::text,p_texts) returning revision into new_revision;
 update public.research_copy_versions set version=regexp_replace(current_copy.version,'r[0-9]+$','r')||((substring(current_copy.version from 'r([0-9]+)$'))::bigint+1) where revision=new_revision;
 return public.get_research_content(new_revision);
end; $function$
;
revoke all on function public.github_save_research_content(text,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.github_save_research_content(text,bigint,jsonb) to service_role;
CREATE OR REPLACE FUNCTION public.github_set_private_response_deleted(p_reader_token text, p_response_id bigint, p_deleted boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
begin
 -- Authentication is enforced by the service-role-only grant and the Edge session check.
 if p_response_id is null or p_response_id <= 0 or p_deleted is null then
   raise exception 'Invalid entry.';
 end if;
 update public.responses
 set deleted_at = case when p_deleted then coalesce(deleted_at, pg_catalog.now()) else null end
 where id = p_response_id;
 return found;
end;
$function$
;
revoke all on function public.github_set_private_response_deleted(text,bigint,boolean) from public,anon,authenticated;
grant execute on function public.github_set_private_response_deleted(text,bigint,boolean) to service_role;
CREATE OR REPLACE FUNCTION public.github_consume_research_login_attempt(p_reader_token text, p_bucket text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
declare current_attempts integer; global_attempts integer; key text;
begin
-- Authentication is enforced by the service-role-only grant and the Edge session check.
 if p_bucket is null or p_bucket !~ '^[A-Za-z0-9_-]{43}$' then return false; end if;
 perform pg_catalog.pg_advisory_xact_lock(714093823::bigint);
 delete from public.research_login_limits where window_start<pg_catalog.statement_timestamp()-interval '1 day';
 foreach key in array array['global',p_bucket] loop
  insert into public.research_login_limits(bucket,window_start,attempts) values(key,pg_catalog.statement_timestamp(),1)
  on conflict(bucket) do update set
  attempts=case when public.research_login_limits.window_start<pg_catalog.statement_timestamp()-interval '15 minutes' then 1 else public.research_login_limits.attempts+1 end,
  window_start=case when public.research_login_limits.window_start<pg_catalog.statement_timestamp()-interval '15 minutes' then pg_catalog.statement_timestamp() else public.research_login_limits.window_start end;
 end loop;
 select attempts into current_attempts from public.research_login_limits where bucket=p_bucket;
 select attempts into global_attempts from public.research_login_limits where bucket='global';
 return current_attempts<=5 and global_attempts<=100;
end; $function$
;
revoke all on function public.github_consume_research_login_attempt(text,text) from public,anon,authenticated;
grant execute on function public.github_consume_research_login_attempt(text,text) to service_role;
CREATE OR REPLACE FUNCTION public.github_get_private_conversation_contacts(p_reader_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY INVOKER
 SET search_path TO ''
AS $function$
begin
 -- Authentication is enforced by the service-role-only grant and the Edge session check.
 return (select coalesce(jsonb_agg(jsonb_build_object('id',id,'contact',contact,'consent_date',consent_date,'consent_version',consent_version,'consent_text',consent_text,'notice_text',notice_text) order by consent_date desc,id),'[]'::jsonb)
 from public.research_conversation_contacts where consent_date>=(current_date-interval '1 year')::date);
end; $function$
;
revoke all on function public.github_get_private_conversation_contacts(text) from public,anon,authenticated;
grant execute on function public.github_get_private_conversation_contacts(text) to service_role;
create table public.research_github_admin_sessions(token_hash text primary key, expires_at timestamptz not null);
alter table public.research_github_admin_sessions enable row level security;
revoke all on public.research_github_admin_sessions from public,anon,authenticated;
grant select,insert,delete on public.research_github_admin_sessions to service_role;
create function public.github_admin_ready() returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from vault.secrets where name='research_github_admin_credentials');
$$;
create function public.github_bootstrap_admin(p_username text,p_password text) returns boolean language plpgsql security definer set search_path='' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(714093829::bigint);
 if p_username<>'jonas' or char_length(p_password) not between 1 and 200 or public.github_admin_ready() then return false; end if;
 perform vault.create_secret(jsonb_build_object('username',p_username,'password_hash',extensions.crypt(p_password,extensions.gen_salt('bf',12)))::text,'research_github_admin_credentials','Admin credentials migrated after successful sign-in to the existing site.');
 return true;
end; $$;
create function public.github_admin_login(p_username text,p_password text) returns text language plpgsql security definer set search_path='' as $$
declare settings jsonb; token text;
begin
 if p_username is null or p_password is null or char_length(p_username)>100 or char_length(p_password)>200 then return null; end if;
 select decrypted_secret::jsonb into settings from vault.decrypted_secrets where name='research_github_admin_credentials';
 if settings is null or settings->>'username'<>p_username or coalesce(extensions.crypt(p_password,settings->>'password_hash')=(settings->>'password_hash'),false) is not true then return null; end if;
 token:=pg_catalog.encode(extensions.gen_random_bytes(32),'hex');
 delete from public.research_github_admin_sessions where expires_at<pg_catalog.statement_timestamp();
 insert into public.research_github_admin_sessions(token_hash,expires_at) values(pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(token,'UTF8')),'hex'),pg_catalog.statement_timestamp()+interval '12 hours');
 return token;
end; $$;
create function public.github_admin_session_valid(p_token text) returns boolean language sql stable security invoker set search_path='' as $$
select coalesce(p_token ~ '^[a-f0-9]{64}$' and exists(select 1 from public.research_github_admin_sessions where token_hash=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(p_token,'UTF8')),'hex') and expires_at>pg_catalog.statement_timestamp()),false);
$$;
create function public.github_admin_logout(p_token text) returns void language sql security invoker set search_path='' as $$
delete from public.research_github_admin_sessions where token_hash=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(p_token,'UTF8')),'hex');
$$;
revoke all on function public.github_admin_ready(),public.github_bootstrap_admin(text,text),public.github_admin_login(text,text),public.github_admin_session_valid(text),public.github_admin_logout(text) from public,anon,authenticated;
grant execute on function public.github_admin_ready(),public.github_bootstrap_admin(text,text),public.github_admin_login(text,text),public.github_admin_session_valid(text),public.github_admin_logout(text) to service_role;
commit;
