# Intentional Training Notes iOS

Native SwiftUI MVP for the Intentional Training Notes PRD.

## Open

Open `IntentionalTrainingNotes.xcodeproj` in Xcode, then run the `IntentionalTrainingNotes` scheme on an iOS simulator or device.

## Target

- iOS 13+
- SwiftUI with `AppDelegate` / `SceneDelegate`
- Local JSON persistence in Application Support
- No external dependencies

## Verify

When full Xcode is installed and selected:

```sh
xcodebuild -scheme IntentionalTrainingNotes -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild -scheme IntentionalTrainingNotes -destination 'platform=iOS Simulator,name=iPhone 15' test
```
