#!/bin/sh
set -eu
# Uses an isolated, disposable local database, never the hosted project.
container="matmind-v2-postgres"
docker exec "$container" psql -U postgres -v ON_ERROR_STOP=1 -c 'DROP DATABASE IF EXISTS matmind_test;'
docker exec "$container" psql -U postgres -v ON_ERROR_STOP=1 -c 'CREATE DATABASE matmind_test;'
# Roles live at cluster scope and may already have been created by another run.
sed '/create role /d' supabase/tests/bootstrap.sql > /tmp/matmind-test-bootstrap.sql
cat /tmp/matmind-test-bootstrap.sql supabase/migrations/*.sql supabase/tests/social.sql supabase/tests/qr.sql supabase/tests/profile.sql | docker exec -i "$container" psql -U postgres -d matmind_test -v ON_ERROR_STOP=1
