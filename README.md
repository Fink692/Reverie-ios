# Reverie

Native SwiftUI iOS 17+ roleplay studio. Fictional commerce, banking, and creator dashboards, editable scenes and totals, immediate simulated events, searchable activity, local notification sessions, saved cue presets, alert queue with individual cancellation, JSON import/export, persistence, light/dark appearance, and reset controls. Notifications use natural event titles and are sent by Reverie. Simulation context is explained in onboarding and Settings.

## Open and run

On a Mac with Xcode 16 or later:

```sh
cd SceneKitDemo
open Reverie.xcodeproj
```

A real Xcode project is included, generated with official XcodeGen 2.46.0. No project generator is needed just to open and run it. To change project configuration, edit `project.yml` and regenerate with `brew install xcodegen && xcodegen generate`.

Select the Reverie scheme and an iPhone simulator, then Run. To install on a physical iPhone, select your Apple developer team under Signing & Capabilities and choose a unique bundle identifier. No server or APNs certificate is needed for local notifications.

Run the unit suite with `./scripts/verify-macos.sh`. Override `IOS_TEST_DESTINATION` for an installed simulator, e.g. `platform=iOS Simulator,name=iPhone 17`. The script uses the included project, or regenerates it when XcodeGen is installed. It discovers an installed compatible simulator by default and also compiles for unsigned physical devices. The full native suite covers accounting, invalid amounts, stable scene references, file recovery, scene deletion, onboarding, event creation, scene switching, and scheduling/cancelling notification sessions.

## Use

1. Dashboard: switch scenes from the chevrons; edit name, type, currency, and totals with the pencil.
2. Studio: compose an event and add it to the dashboard, or schedule 1–20 alerts separately. Multiple notifications arrive ten seconds apart. Scheduling does not change dashboard totals.
3. Activity: review and search the active scene's recorded events.
4. Settings: create, edit, delete, or select scenes; export a JSON file or import a saved session; change appearance; cancel notifications; reset data.
5. Studio saved cues: save the current setup, edit and reuse named presets, and review or cancel individual queued alerts.

Notification permission is requested only when cueing alerts. Focus modes, notification settings, and system delivery policy can affect presentation. Real system notifications cannot use another installed app's name/icon. Charts show explicitly labeled illustrative curves, not invented historical records. All currencies use the device locale for formatting. No real financial or commerce services are connected.

## Validation status

The shared Foundation code compiled with Swift 6.0.3 in an official Linux Swift container. **27 shared-logic and storage tests passed**, including accounting, refunds, localized numeric input, scheduling plans, persistence, recovery backups, and failed writes. Run `./scripts/verify-core.sh` to reproduce them with Swift 6+ or Docker.

Native Swift source and test grammar passed Swift frontend parsing. XcodeGen generated and validated the included project with complete configuration presets and all source/test references. Full Apple SDK compilation, native Store tests, UI tests, simulator behavior, accessibility runtime checks, and signing remain unverified. The hosted macOS workflow will perform unsigned device compilation and simulator unit/UI tests after the project is pushed to an accessible repository. See `Verification/STATUS.md` and the retained test output.

## Design references

- Apple notifications HIG: https://developer.apple.com/design/human-interface-guidelines/notifications
- Apple local notifications API: https://developer.apple.com/documentation/usernotifications
- Shopify app overview: https://help.shopify.com/en/manual/shopify-admin/shopify-app
- Shopify analytics: https://help.shopify.com/en/manual/reports-and-analytics/shopify-reports/overview-dashboard

References informed native navigation, concise alerts, sales/order metrics, and activity patterns. Reverie uses its own identity and fictional scenes, rather than bank/Shopify branding.

## Build without owning a Mac

This repository includes `.github/workflows/ios.yml`. Push the project to a GitHub repository with Actions enabled. The workflow first tests shared Swift logic on Linux. A standard `macos-15` runner then installs XcodeGen, discovers a compatible iPhone simulator, compiles the application for physical iOS devices without signing, runs simulator unit and UI tests, launches the app, and uploads screenshots, test results, logs, and a simulator app archive. The workflow runs on pushes to main and can also be started from Actions → iOS build and test → Run workflow.

The simulator artifact does not require an Apple developer account. It runs on a Mac's iOS Simulator, not on a physical iPhone. Physical installation or TestFlight distribution still requires Apple signing through your developer account. Hosted Mac builds use GitHub Actions minutes under the repository owner's plan.

The connected GitHub integration could read repositories but returned HTTP 403 when asked to create `Fink692/reverie-ios`. The remote workflow has not run. Once an empty repository exists and the integration has access, the prepared commit can be pushed and the actual build results reviewed.

## Notifications and recovery details

Supported events include new orders, deposits, payouts, subscribers, outgoing payments, and order refunds. Outgoing events show negative amounts; subscribers show no monetary amount. Bank deposits update balance and income, creator payouts update balance and earnings, and refunds reduce sales without removing order history. Dashboard totals are bounded, and insufficient balance prevents an outgoing event from being recorded.

Deleting a scene removes its recorded events and cancels its queued alerts. Cancelling or resetting a session also invalidates a batch still being scheduled. Tapping a notification selects its scene and opens Dashboard. A corrupt save is kept in a uniquely named recovery file before new data replaces it.

## Restoring a session

Settings → Export session writes a native `.json` file through Files. Imports include all scenes, activity, and saved cues, and require confirmation before replacing current data. Import validates file size (up to 2 MB), identities, numerical bounds, references, and cue settings before changing anything; queued alerts are cleared after replacement. Older exports without saved cues still load. Invalid imports leave the current session unchanged.

Saved cues store event type, amount, details, start delay, and alert count. Loading a cue fills Studio without scheduling it. The queued-alert view shows payloads, scene names, scheduled times, and per-alert cancellation. Queued iOS requests are not re-scheduled automatically when a session is imported.
