# Shared-link website implementation

Target host: https://matmindbjj.lovable.app/

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
`supabase/migrations/20261104160002_invitation_previews.sql`. A full active bearer
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
6. Set `AppLinksEnabled` to true in `IntentionalTrainingNotes/Info.plist`, regenerate
   signing profiles if needed, and ship the iOS build. It remains false in this
   change because the hosting and signed-device checks are not yet complete.

No website publication or hosted migration is performed merely by preparing these
changes. The website PR's `docs/ios-invitation-links.md` contains the route and
deployment details. Social applications control their own preview crops and caches.
