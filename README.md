# Mat Mind iOS

Native SwiftUI app for planning training with partners, sharing completed sessions and maintaining weekly friendship streaks.

Open `IntentionalTrainingNotes.xcodeproj`, select the `IntentionalTrainingNotes` scheme and run on iOS 17 or later. The existing production bundle identifier is retained.

Production code lives in `MatMind/`. The design system comes from the pinned prototype in `Prototypes/MatMind/DesignSystem/`. Prototype seed data and demo features are excluded from the production target.

The app is configured with the supplied Supabase project URL and publishable key. **Hosted migrations, auth providers and server functions still need deployment/configuration.** See [deployment and validation instructions](docs/mat-mind-v2-deployment.md).

Existing notebooks stay private and local. Their sole entry point is **Profile → Settings → Previous training data**, shown only when genuine legacy records exist. It contains a read-only archive and native ZIP export. Migration preserves original JSON, dates, relationships and attachments; it never generates social posts, attendance or streak credit.

```sh
xcodebuild -scheme IntentionalTrainingNotes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```

The previous notebook implementation remains in `IntentionalTrainingNotes/` for decoding, compatibility and migration tests. It is not the production navigation root.
