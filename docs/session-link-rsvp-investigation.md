# Declined session returns to Going

## Confirmed cause

Opening a session invitation calls `join_link` from
`LiveMatMindRuntime.connect` in `MatMind/App/MatMindRoot.swift` (also used by
the older `SocialAppModel.redeemPendingLink` path). The server's command
previously used this participant upsert:

```sql
on conflict(session_id,user_id) do update set rsvp='going';
```

Every new link open gets a new command idempotency key. Retrying the same
request is safe, but opening the link again executes the upsert again and
overwrites `declined` with `going`. It also answers an existing `invited` RSVP
without an explicit response.

The decline itself is persisted correctly by `set_rsvp`. A database regression
test confirms `declined` appears in a fresh `snapshot()` before reopening the
link, then fails on the original implementation because the next link open
changes it to `going`.

Ordinary foreground refresh only fetches a snapshot; it does not set an RSVP.
Startup also redeems a pending invitation, which can trigger the overwrite.
An app reopen without a pending link did not reproduce an RSVP write in this
investigation. No production account or session was inspected.

## Fix and rollout

`20261105053014_preserve_session_link_rsvp.sql` changes only the `join_link`
conflict action to `do nothing`. First-time recipients still join as before.
Existing participants keep their saved RSVP, including pending invitations and
declines. An explicit Join / Join session action uses `set_rsvp` to change a
decline back to going. Capability validation, session locking, actor locking,
command receipts and function grants are retained.

Deployed to Supabase project `cmiqavyrazypmulrfezj` on November 5, 2026 at
05:30 UTC. The repository migration filename matches the version assigned by
Supabase's migration service (`20261105053014`); its SQL is unchanged from the
migration originally merged in PR #67. The fix is active for existing app
builds. It does not infer or restore previously overwritten responses; affected
members can explicitly decline again.

From an up-to-date checkout of `main`, check deployment with the Supabase CLI:

```sh
git switch main
git pull --ff-only origin main
supabase login
supabase link --project-ref cmiqavyrazypmulrfezj
supabase db push --dry-run
```

The hosted migration history includes all repository migrations through
`20261105053014_preserve_session_link_rsvp.sql`. The dry run should find no
pending migrations for this checkout. For device acceptance, decline a session
and reopen its invitation to confirm the member is not marked Going again.
No Edge Function deployment or new iOS build is required for this fix.

Hosted readback confirms the deployed command source exactly matches the
expected tested change (source MD5 `e076f419c97d22e6ddb27bcd3f320781`). Function
grants, SECURITY DEFINER and empty search path are unchanged; anonymous command
execution remains denied. Security advisor findings are unchanged from the
pre-deployment baseline. Verification did not alter existing user responses or
create test accounts in production; behavioral regression tests ran locally.

## Regression coverage

`supabase/tests/session_link_rsvp.sql` runs in the local database harness and CI.
It covers decline persistence in snapshots, repeated link opens with fresh
request keys, replaying an earlier join receipt after declining, replacement
invitation links, first-time joins, explicit rejoining, preserving pending
invitations, and rejection of revoked, unknown, expired, blocked and cancelled
invitations. The reproduction fails before the migration and passes after it.

The full `sh scripts/test-database.sh` run passed on PostgreSQL 17, including
all existing SQL suites, the 14 new assertions and username concurrency checks.
`git diff --check` passed. No Swift files changed; device acceptance was not run
in this Linux environment.
