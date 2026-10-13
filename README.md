# Reverie

Native SwiftUI iOS 17+ roleplay studio. Fictional commerce, banking, investing, crypto wallet, prediction, and creator dashboards, editable scenes and totals, immediate simulated events, searchable activity, local notification sessions, saved cue presets, alert queue with individual cancellation, JSON import/export, persistence, light/dark appearance, and reset controls. Notifications use natural event titles. The Studio build uses Reverie’s name and icon; optional brand variants use their own configured display names and official reference icons. Simulation context is explained in onboarding and Settings.

## Open and run

On a Mac with Xcode 16 or later:

```sh
cd Reverie-ios
open Reverie.xcodeproj
```

A real Xcode project is included, generated with official XcodeGen 2.46.0. No project generator is needed just to open and run it. To change project configuration, edit `project.yml` and regenerate with `brew install xcodegen && xcodegen generate`.

Select the Reverie scheme and an iPhone simulator, then Run. To install on a physical iPhone, select your Apple developer team under Signing & Capabilities and choose a unique bundle identifier. No server or APNs certificate is needed for local notifications.

Run the unit suite with `./scripts/verify-macos.sh`. Override `IOS_TEST_DESTINATION` for an installed simulator, e.g. `platform=iOS Simulator,name=iPhone 17`. The script uses the included project, or regenerates it when XcodeGen is installed. It discovers an installed compatible simulator by default and also compiles for unsigned physical devices. The full native suite covers accounting, invalid amounts, stable scene references, file recovery, scene deletion, onboarding, event creation, scene switching, and scheduling/cancelling notification sessions.

## Use

1. Dashboard: switch scenes from the chevrons; edit name, type, currency, and totals with the pencil.
2. Studio: choose a notification template or style, customize its message and timing, and schedule 1–20 alerts. Supported accounting events can also be added to the dashboard; scheduled alerts leave totals unchanged.
3. Activity: review and search the active scene's recorded events.
4. Settings: create, edit, delete, or select scenes; export a JSON file or import a saved session; change appearance; cancel notifications; reset data.
5. Studio saved cues: save and reuse the complete setup, including style, title, order information, and timing; review or cancel individual queued alerts.

Notification permission is requested only when cueing alerts. Focus modes, notification settings, and system delivery policy can affect presentation. Each build variant has its own unique bundle identity, display name, and icon. iOS renders notifications using that installed variant’s identity. Charts use editable fictional scene curves. All currencies use the device locale for formatting. No real financial or commerce services are connected.

## Validation status

The shared Swift suite passes 47 tests with Swift 6.0.3. Native Apple SDK and simulator verification of the latest notification and prediction-screen changes is pending. Previous native results, screenshots, package checks, and current limitations are recorded in [Verification/STATUS.md](Verification/STATUS.md). Physical-device installation and distribution signing still require an Apple account and a device; the hosted packages are unsigned.

## Design references

- Apple notifications HIG: https://developer.apple.com/design/human-interface-guidelines/notifications
- Apple local notifications API: https://developer.apple.com/documentation/usernotifications
- Shopify app overview: https://help.shopify.com/en/manual/shopify-admin/shopify-app
- Shopify analytics: https://help.shopify.com/en/manual/reports-and-analytics/shopify-reports/overview-dashboard

References informed native navigation, concise alerts, sales/order metrics, and activity patterns. The Studio build uses Reverie’s identity. Optional brand variants use public App Store artwork with provenance in `References/Branding`, unique Reverie bundle identifiers, and fictional local scenes.

## Build without owning a Mac

This repository includes `.github/workflows/ios.yml`. Push the project to a GitHub repository with Actions enabled. The workflow first tests shared Swift logic on Linux. A standard `macos-15` runner then installs XcodeGen, discovers a compatible iPhone simulator, compiles the application for physical iOS devices without signing, runs simulator unit and UI tests, launches the app, and uploads screenshots, test results, logs, and a simulator app archive. The workflow runs on pushes to main and can also be started from Actions → iOS build and test → Run workflow.

The simulator artifact does not require an Apple developer account. It runs on a Mac's iOS Simulator, not on a physical iPhone. Physical installation or TestFlight distribution still requires Apple signing through your developer account. Hosted Mac builds use GitHub Actions minutes under the repository owner's plan.

The user-provided repository is https://github.com/Fink692/Reverie-ios. It is public and contains the source plus hosted build workflow.

## Notifications and recovery details

Studio offers 33 notification styles and 35 editable templates, filtered for the active scene. They cover Shopify orders, refunds, payouts, fulfillment and inventory; bank payments and balances; investing, crypto and prediction activity; creator milestones; and custom messages.

Customize the title and details, amount, customer or subscriber, item quantity, order number, and relevant outcome. Custom messages support `{scene}`, `{amount}`, `{customer}`, `{items}`, and `{order}` placeholders. The preview reads the installed build’s name and primary icon, with a generic icon fallback when unavailable; iOS uses the installed app’s identity for delivered alerts.

Each session supports 1–20 alerts, a start delay of 2 seconds to 24 hours, and at most 60 queued alerts across scenes. The repeat-interval picker offers 5, 10, 15, 20, 30, and 60 seconds; loaded or imported custom intervals within the validated 5–3,600-second range are retained. A queued confirmation appears only after iOS accepts the requests. Notice-only styles can be scheduled without changing accounting totals.

Supported accounting events include new orders, deposits, payouts, subscribers, outgoing payments, and order refunds. Outgoing events show negative amounts; subscribers show no monetary amount. Bank deposits update balance and income, creator payouts update balance and earnings, and refunds reduce sales without removing order history. Dashboard totals are bounded, and insufficient balance prevents an outgoing event from being recorded.

Deleting a scene removes its recorded events and cancels its queued alerts. Cancelling or resetting a session also invalidates a batch still being scheduled. Tapping a notification selects its scene and opens Dashboard in Studio; a matching branded variant opens its immersive scene. A corrupt save is kept in a uniquely named recovery file before new data replaces it.

## Restoring a session

Settings → Export session writes a native `.json` file through Files. Imports include all scenes, activity, and saved cues, and require confirmation before replacing current data. Import validates file size (up to 2 MB), identities, numerical bounds, references, and cue settings before changing anything; queued alerts are cleared after replacement. Older exports without saved cues still load. Invalid imports leave the current session unchanged.

Saved cues retain event type, notification style, custom title, amount, details, customer, item quantity, order number, start delay, repeat interval, and alert count. Loading a cue fills Studio without scheduling it; incompatible styles require a matching scene. Older cues retain their automatic style and ten-second interval. The queued-alert view shows payloads, scene names, scheduled times, and per-alert cancellation. Queued iOS requests are not re-scheduled automatically when a session is imported.

## Immersive scenes

Dashboard → Open scene hides Studio navigation and opens the selected store, bank, portfolio, wallet, or prediction scene. Commerce layouts reference Shopify's current official iPhone screenshots: black metric/chart header, blue plots, white rounded panels, floating navigation, order rows, filters and status chips. Home, Orders, Products, and Menu are interactive. Products, orders, metrics, current/prior chart curves, payouts and fulfillment state can be edited locally. Shopify-style order wording uses item quantity and the selected store name.

Bank playback offers Chase, Bank of America, Wells Fargo, Citi, Capital One, HSBC UK, Barclays UK, Lloyds, NatWest, Monzo, Revolut and Starling. These are 12 named references, not an exhaustive list of every major bank worldwide. Each has a distinct reference-based overview, account/activity pages, editable balances, simulated payments/deposits, and persisted card controls. Change the scene currency in Studio for the desired region.

Reference provenance and known differences are in `References/Shopify/README.md` and `References/Banks/README.md`. App Store images include promotional framing; the implementation reproduces visible in-app patterns, and provides optional playback controls that can be hidden with Clean playback. It is not certified as pixel-identical to complete third-party apps. Optional variants supply matching reference icons and brand display names, but exact genuine installed display-name values have not been verified. Commerce orders use an original cash-register sound approximation; the exact Shopify Cha-Ching recording has not been verified.

The workflow also produces `Reverie-unsigned.ipa`. This is a physical-device build package, **not directly installable until signed** using an Apple account/developer team or an authorized sideloading tool. The simulator archive runs on a Mac's iOS Simulator. Neither artifact grants access to real bank or Shopify services.

## Investing, wallets, and predictions

Investing offers Robinhood, Wealthsimple, and Coinbase appearances with editable assets, price charts, cash, average cost, buy/sell review and confirmation, and saved transaction history. Coinbase Send and Receive change token units independently from cash. Wealthsimple starts in CAD in its branded build; other investing variants start in USD.

Wallets offer MetaMask, Phantom, and Trust Wallet appearances, token balances, asset details, public-address receive cards and QR codes, send/receive review and confirmation, and local swaps at the scene's editable token prices. The app does not request recovery phrases or private keys and never broadcasts a transaction.

Prediction playback follows Polymarket’s sports-first Home, with league controls, game cards, editable teams, scores, game state, and probabilities. Search opens generic event markets and categories; market details include Yes/No positions, charts, cash, share-based buy/sell review and confirmation, and saved history. Complete authenticated screen fidelity remains unverified.

Each transaction saves its balances, holdings, and record together. Invalid values, insufficient balances, stale quotes, overflow, and failed disk writes leave the previous session intact. Imports include all profiles and transaction histories; older archives without the new profiles still load. Reference evidence is in [Markets](References/Markets/README.md), [Wallets](References/Wallets/README.md), and [Prediction](References/Prediction/README.md).

## Separate branded packages

Run `./scripts/verify-macos.sh device`, then `./scripts/build-brand-variants.sh` on a Mac. The first build compiles all reference icons once; packaging reuses that executable and icon catalog and configures each app through its runtime metadata. It produces 20 unsigned packages and a verified SHA-256 manifest in `brand-artifacts` (uploaded as `Reverie-unsigned-apps`): Shopify-style commerce plus Chase, Bank of America, Wells Fargo, Citi, Capital One, HSBC, Barclays, Lloyds Bank, NatWest, Monzo, Revolut and Starling Bank, plus Robinhood, Wealthsimple, Coinbase, MetaMask, Phantom, Trust Wallet, and Polymarket. Use `--only chase` (or another ID from `References/Branding/variants.json`) to build one package. GitHub Actions builds and uploads all 20 automatically.

Each variant launches its matching immersive scene after the roleplay onboarding and on subsequent launches. Branded variants restore their configured appearance on relaunch while preserving existing scene data. Reset clears the session and restores starter account data. Clean playback is enabled by default in variants. Return to Studio from a profile/menu → Close scene, or hold the bank name for two seconds in banking. Studio → Settings can show the extra playback controls again. All variants remain local fictional simulators with separate storage; their identities do not replace the genuine apps. See `INSTALL.md` for signing and installation options.

Clean playback hides additional close buttons and appearance selectors. Enable it in Settings when preparing a capture. It preserves the normal local controls and saved session.
