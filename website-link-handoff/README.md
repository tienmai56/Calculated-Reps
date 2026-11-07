# Shared-link website implementation

Target host: https://mymatmonkey.com/

Generated HTTPS links, preview metadata, the verification script and the signed
app's Associated Domains now select the custom domain. The app still accepts
`matmonkey.lovable.app`, retired `matmindbjj.lovable.app` and `matmind://` invitations
so existing codes keep their native behavior. The previous Lovable Associated
Domain remains in the entitlement for already-shared universal links.

This custom-domain change is prepared in source, not verified live. Connect
`mymatmonkey.com` to the existing website through Lovable's custom-domain setup,
using the DNS records Lovable provides. Publish the updated website, check the
association and preview routes on the custom domain, then ship a new signed iOS
build. Configuring `auth.mymatmonkey.com` in Supabase does not connect the website
at `mymatmonkey.com`. Domain purchases alone do not publish the website.

The actual website implementation is in
[mat-monkey-web](https://github.com/tienmai56/mat-monkey-web).
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

## Session preview contract repair — November 6, 2026

The hosted `follows_and_private_invitations` migration replaced the session
summary with `{ "kind": "session" }`. The published website requires the title,
start time, timezone, venue, participants, participant count and focus fields;
it rejects the incomplete result, producing HTTP 503 instead of a session card.

`20261106081650_restore_session_invitation_previews.sql` restores that limited
summary and is deployed to the social project. It preserves active-token,
organizer, planned-session and block checks. Viewing a preview never accepts an
invitation. Friend and goal previews remain generic; notes and nested focus
details remain private.

Validation reproduced the incomplete-response failure, then passed the local
database regression suite, the published website's validator and metadata
formatter against a real PostgreSQL response, and isolated hosted preview tests
whose fixtures were rolled back. Anonymous table access remains denied.

For device acceptance after custom-domain rollout, share a fresh `https://mymatmonkey.com/session/…`
link in Messages and confirm the card. Links using the retired
`matmindbjj.lovable.app` address or `matmind://` cannot fetch this website's
preview. Existing Messages cards can retain earlier responses. End-to-end live
HTML/image checks and a physical Messages check still require a real shared URL;
the execution environment cannot reach the custom domain under its current network policy.
