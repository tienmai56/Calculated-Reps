# Shared-link website implementation

Target host: https://matmonkey.lovable.app/

The published site moved from `matmindbjj.lovable.app` to this host. The old host
now returns "Project not found" rather than redirecting. Generated HTTPS links,
preview metadata, the verification script and the signed app's Associated Domains
must all use the current host. Existing `matmind://` links keep their native
fallback behavior, but messaging apps cannot fetch rich previews for them. The
App Store build needs an iOS update to start copying the new HTTPS invitation links.

The actual website implementation is in
[PR #1](https://github.com/tienmai56/your-note-haven/pull/1) in `your-note-haven`.
It handles friend, training-session, and shared-goal URLs, serves Apple's association
JSON, and generates real PNG social cards. Prefer it over the older static
`public/invite.html` reference, which does not provide rich previews.

Training previews show the approved session title, date/time and timezone, gym,
confirmed participant names, and top-level focus names. They use the existing
Paper 3 background, Coral 500 date stub, original monochrome Silverback, Bricolage
Grotesque, Archivo, and Lucide artwork. Full notes and nested focus details remain
inside the app. Friend and goal cards remain generic.

The website reads the social project's deliberately public, read-only
`invitation_preview(link_kind,token)` RPC, added by
`supabase/migrations/20261104085624_invitation_previews.sql`. A full active bearer
token authorizes only this summary; fetching the preview never redeems the link,
joins a session, or accepts a goal. Existing table RLS is unchanged.

## Rollout order

1. Apply the reviewed preview migration to the social Supabase project.
2. Configure website runtime bindings `MAT_MONKEY_SUPABASE_URL` and
   `MAT_MONKEY_SUPABASE_PUBLISHABLE_KEY` for that same project. The website's existing
   `VITE_SUPABASE_*` settings belong to a different project. Use a publishable/anon
   key, never a service-role key.
3. Confirm the production App Identifier Prefix matches
   `9R4A2F8F94.com.tienmai.intentionaltrainingnotes`, then publish the website.
4. Run `SESSION_SHARE_TOKEN=<real active token> node scripts/verify-share-host.mjs`
   from this repository. It verifies the live association, session HTML, and PNG
   without printing or redeeming the token.
5. Verify physical-device universal-link behavior and sign-in continuation. Installed
   app: opens the exact invitation. No app: web summary plus App Store. Messenger's
   browser: explicit **Open in Mat Monkey** action. After installing, return to the
   original invitation; cross-install deferred linking is not implemented.
6. `AppLinksEnabled` is now true in `IntentionalTrainingNotes/Info.plist` following
   live association, PNG, and backend-lookup checks. Regenerate signing profiles
   if needed and verify a signed iPhone build before shipping it. Existing installed
   builds keep their current sharing behavior until updated.

The preview migration is applied and the website is published. Live checks passed
for the Apple association JSON, 1200 × 630 PNG, and unavailable invitation/image
responses (preview version `20261104.2`). The website's `docs/ios-invitation-links.md`
contains route details. Social applications control their own preview crops and
caches. A signed iPhone release remains a separate step.
