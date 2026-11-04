#!/bin/sh
set -eu
# Uses an isolated, disposable local database, never the hosted project.
container="matmind-v2-postgres"
docker exec "$container" psql -U postgres -v ON_ERROR_STOP=1 -c 'DROP DATABASE IF EXISTS matmind_test;'
docker exec "$container" psql -U postgres -v ON_ERROR_STOP=1 -c 'CREATE DATABASE matmind_test;'
# Roles live at cluster scope and may already have been created by another run.
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;
END $$;
SQL
sed '/create role /d' supabase/tests/bootstrap.sql > /tmp/matmind-test-bootstrap.sql
cat /tmp/matmind-test-bootstrap.sql supabase/migrations/*.sql supabase/tests/social.sql supabase/tests/qr.sql supabase/tests/persistent_friend_codes.sql supabase/tests/profile.sql supabase/tests/notifications.sql supabase/tests/mentions.sql supabase/tests/usernames.sql supabase/tests/goal_sharing.sql supabase/tests/session_edit.sql supabase/tests/follows.sql supabase/tests/invitation_previews.sql | docker exec -i "$container" psql -U postgres -d matmind_test -v ON_ERROR_STOP=1
python3 scripts/test-username-concurrency.py --container "$container"
