-- Local PostgreSQL fixture for the Supabase-owned auth/storage interfaces.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create schema storage;
create schema extensions;
create table auth.users(id uuid primary key, created_at timestamptz default now());
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth,storage to anon,authenticated,service_role;
grant execute on function auth.uid() to authenticated;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
alter table storage.objects enable row level security;
grant select,insert on storage.objects to authenticated;

-- Reproduce hosted Supabase's explicit per-role function defaults so tests catch
-- grants that a REVOKE FROM PUBLIC alone would leave behind.
alter default privileges in schema public grant execute on functions to anon,authenticated,service_role;
