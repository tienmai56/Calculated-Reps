# Lovable invitation-link handoff

Target website: https://matmindbjj.lovable.app/

The website repository has now been supplied, and the actual TanStack Start implementation is prepared in [draft PR #1](https://github.com/tienmai56/your-note-haven/pull/1). It serves the association JSON through the custom server entry and adds native friend/session routes. Prefer that implementation over the static reference assets below. Production build, type checking, focused linting, six tests and HTTP checks of the built Cloudflare worker passed. The live site has not been republished.

The public site responds successfully. As checked on November 1, 2026 (Pacific), both `/.well-known/apple-app-site-association` and `/friend/test` return HTTP 404. No live website changes have been made.

The iOS project now declares this host and its Associated Domains entitlement. `AppLinksEnabled` is deliberately false until the web setup is verified, so invitation generation continues to use `matmind://`.

## Add these files to the actual Lovable website repository

1. Copy `public/.well-known/apple-app-site-association` into the website's public assets. It must be published at the exact extensionless URL below, with HTTP 200, a JSON content type and no redirects. A normal React SPA fallback is not sufficient.
2. Verify the AASA app identifier against the App Identifier Prefix in the production app's provisioning profile. `9R4A2F8F94` is the development team configured in this Xcode project; replace it if the production prefix differs.
3. Add actual website routes `/friend/:token`, `/session/:token` and `/goal/:token` (shared goals). `public/invite.html` supplies a self-contained fallback view to adapt to the site's router, or to serve through internal rewrites that preserve the original invitation path. Merely copying `invite.html` into public assets does not create those routes. Keep the existing homepage intact.
4. Publish the Lovable site and verify its deployed responses. If this hosting setup cannot serve the extensionless JSON file with the required response, use a controlled host that can.

The fallback provides an explicit Open in Mat Monkey button and the supplied App Store listing. It never exposes session content, redeems a token, collects analytics or uploads legacy data. Users who install must return to their original invitation; this is not deferred deep linking across installation.

## Verify before enabling HTTPS invitation generation

```sh
curl -i https://matmindbjj.lovable.app/.well-known/apple-app-site-association
curl -i https://matmindbjj.lovable.app/friend/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
curl -i https://matmindbjj.lovable.app/session/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

The association URL must return the JSON file, not the home page. Both invitation paths must return the intended fallback. The sample token is only for testing page rendering; it is not a valid backend invitation.

Regenerate the app's signing profile with Associated Domains, rebuild/install the app, and test valid server-issued friend/session invitations on a physical device. Verify installed/uninstalled behavior, expired links, and sign-in continuation. Keep the custom URL scheme registered for the fallback button.

Once verified, set `AppLinksEnabled` to true in the production Info.plist. Do not change `AppStoreURL` into an invitation hostname; it remains the installation destination.
