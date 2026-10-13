# Reverie

Native SwiftUI iOS 17+ roleplay studio. Fictional commerce, banking, and creator dashboards, editable scenes and totals, immediate simulated events, searchable activity, local notification sessions, JSON export, persistence, light/dark appearance, and reset controls. Notifications use natural event titles and are sent by Reverie. Simulation context is explained in onboarding and Settings.

## Open and run

On a Mac with Xcode 16 or later:

```sh
brew install xcodegen
cd SceneKitDemo
xcodegen generate
open Reverie.xcodeproj
```

Select the Reverie scheme and an iPhone simulator, then Run. To install on a physical iPhone, select your Apple developer team under Signing & Capabilities and choose a unique bundle identifier. No server or APNs certificate is needed for local notifications.

Run the unit suite with `./scripts/verify-macos.sh`. Override `IOS_TEST_DESTINATION` for an installed simulator, e.g. `platform=iOS Simulator,name=iPhone 17`. The script generates the project before testing. Tests cover event accounting, invalid amounts, stable scene references, saved-data round trips, persistence, corrupt-save recovery, scene deletion, onboarding, event creation, and scene switching.

## Use

1. Dashboard: switch scenes from the chevrons; edit name, type, currency, and totals with the pencil.
2. Studio: compose an event and add it to the dashboard, or schedule 1–20 alerts separately. Multiple notifications arrive ten seconds apart. Scheduling does not change dashboard totals.
3. Activity: review and search the active scene's recorded events.
4. Settings: create, edit, delete, or select scenes; export a JSON snapshot; change appearance; cancel notifications; reset data.

Notification permission is requested only when cueing alerts. Focus modes, notification settings, and system delivery policy can affect presentation. Real system notifications cannot use another installed app's name/icon. Charts show explicitly labeled illustrative curves, not invented historical records. All currencies use the device locale for formatting. No real financial or commerce services are connected.

## Validation status

Source and project configuration were checked in a Linux workspace. This workspace has no Swift compiler, Xcode, or iOS simulator, so no iOS build or runtime test result is claimed. The XCTest suite is supplied but has not run here. Mac/device verification and signing remain required before release; this is not an App Store approved or production-certified build.

## Design references

- Apple notifications HIG: https://developer.apple.com/design/human-interface-guidelines/notifications
- Apple local notifications API: https://developer.apple.com/documentation/usernotifications
- Shopify app overview: https://help.shopify.com/en/manual/shopify-admin/shopify-app
- Shopify analytics: https://help.shopify.com/en/manual/reports-and-analytics/shopify-reports/overview-dashboard

References informed native navigation, concise alerts, sales/order metrics, and activity patterns. Reverie uses its own identity and fictional scenes, rather than bank/Shopify branding.

## Build without owning a Mac

This repository includes `.github/workflows/ios.yml`. Push the project to a GitHub repository with Actions enabled. A standard `macos-15` runner installs XcodeGen, discovers an available iPhone simulator, compiles the application, runs unit and UI tests, launches the app, and uploads screenshots, the test result bundle, a build log, and a simulator app archive. The workflow runs on pushes to main and can also be started from Actions → iOS build and test → Run workflow.

The simulator artifact does not require an Apple developer account. It runs on a Mac's iOS Simulator, not on a physical iPhone. Physical installation or TestFlight distribution still requires Apple signing through your developer account. Hosted Mac builds use GitHub Actions minutes under the repository owner's plan.

The connected GitHub integration could read repositories but returned HTTP 403 when asked to create `Fink692/reverie-ios`. The remote workflow has not run. Once an empty repository exists and the integration has access, the prepared commit can be pushed and the actual build results reviewed.
