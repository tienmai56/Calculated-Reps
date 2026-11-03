# Google sign-in setup

The installed app uses Supabase's Google OAuth flow with PKCE in an iOS system authentication session. UI preview stays available independently in Debug builds. Apple sign-in is hidden for now; its implementation is retained for later.

## Google Cloud

1. Open Google Cloud Console → Google Auth Platform (or APIs & Services) → Credentials/Clients in the app's Google project.
2. If prompted, configure the consent screen with the Mat Monkey name, support email and developer contact. In Testing mode, add the Google accounts used for verification under Audience → Test users.
3. Create an OAuth client with application type **Web application**. The existing iOS client recorded as `GoogleClientID` in Info.plist is a different client type; this hosted OAuth flow needs the web client.
4. Add this exact authorized redirect URI:

   ```text
   https://cmiqavyrazypmulrfezj.supabase.co/auth/v1/callback
   ```

5. Save the web Client ID and Client secret in the Supabase provider settings below. Keep the secret out of the iOS app, repository and chat.

## Supabase

1. Open project `cmiqavyrazypmulrfezj` → Authentication → Sign In / Providers → Google.
2. Enable Google and enter the web Client ID and Client secret. Leave nonce verification enabled; this browser-based flow does not require disabling it.
3. Save the provider settings.
4. Under Authentication → URL Configuration → Redirect URLs, allow `matmind://auth`. This is the return URL to iOS, separate from Google's hosted callback above.

The settings in `supabase/config.toml` describe local development; they do not automatically enable Google on the hosted project. Hosted provider credentials must be saved separately.

## Verify

1. Pull the app changes, run the IntentionalTrainingNotes scheme, and select **Continue with Google** rather than UI preview.
2. The app checks the public Auth settings before opening the provider sheet. A disabled provider produces an in-app availability message instead of the raw JSON browser error.
3. Complete Google consent. Supabase redirects through its hosted callback to `matmind://auth?code=…`; the app validates that route and exchanges the authorization code with its original PKCE verifier. Errors/cancellation never count as sign-in.
4. A new user is asked to create a mat profile. Returning users see their existing live sessions and friends. Verify sign-out and sign-in again before release.
5. Closing the Google sheet returns to Welcome without an error alert. An account not on the consent screen's test-user list may be rejected until added or the consent configuration is published.

CI covers callback validation, disabled-provider handling, preview isolation and native builds. Completing real Google consent on a device/simulator remains an interactive acceptance check.
