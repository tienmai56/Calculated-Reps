# Quick training log: opt-in database feature

This bundle is disabled by default and intentionally outside `supabase/migrations/`.
Normal Supabase migrations and `supabase db push` do not install it, even after this
code is merged into main. No hosted database has been changed for this feature.

Git branches share whichever Supabase project the app points at. Enabling a flag
does not isolate data: this bundle changes `command`, `snapshot`, attendance and
credits. Use a disposable local database or a separate Supabase preview project
for live branch testing. Do not install it on the shared production project.

## UI preview

Run this branch in Debug and select **Preview without signing in**. Sample-data
quick logs and completion work without installing any database feature.

## Disposable database tests

With the existing local `matmind-v2-postgres` test container running:

```sh
# Default: normal migrations, baseline suites and feature-disabled assertions.
sh scripts/test-database.sh

# Opt in: baseline checks first, then the feature and all training regressions.
QUICK_TRAINING_LOG_ENABLED=1 sh scripts/test-database.sh
```

The harness recreates only its disposable `matmind_test` database. The flag is
strictly `0` or `1`; unset means `0`. CI validates the disabled state on all branches. Only `feat/activity-quick-log-rhythm`
opts in to feature tests, using its temporary PostgreSQL service without deploying
to a hosted project.

## Separate local/preview Supabase database

Apply the normal migration chain to the isolated database first. Configure the
test app to use that database's Supabase API URL and publishable key; leave the
main/release app's backend configuration unchanged. Then, in one administrator
SQL session on that isolated database only:

```sql
SET matmonkey.quick_training_log = 'on';
```

Run `install.sql` in the same session. It checks that explicit session flag before
any schema change and wraps the whole installation in a transaction. A missing
flag fails and rolls back; it does not silently skip or create a migration-history
entry. The bundle is installed once on a fresh test database, not on every launch.

This is an installation gate. Turning the flag off after installation does not
undo the SQL or isolate an already changed database. Reset/recreate the disposable
database or delete the preview project to discard the experiment. No automatic
production installation or rollout is provided. Promote it to a separately
reviewed normal migration only when the feature is ready for main.
