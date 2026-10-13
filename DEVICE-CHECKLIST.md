# Runtime and device verification

## Executed on hosted macOS

- Physical-device Apple SDK compilation without signing.
- 71 native model/storage/Store XCTest cases and 17 UI flows, all passed in [the final hosted run](https://github.com/Fink692/Reverie-ios/actions/runs/38367881655).
- iPhone simulator onboarding, scene editing, accounting, persistence and notification queue scheduling/cancellation.
- Immersive commerce Home, Orders, product editing and order fulfillment.
- All 12 bank themes, account navigation, clean playback and branded relaunch/reset.
- Native commerce and bank screenshots inspected against public references.
- All seven investing/wallet/prediction home styles, Robinhood purchase/relaunch, MetaMask send/history/relaunch, and Polymarket market navigation/trading.
- Customized Shopify cue save/relaunch, exact system-queue payload and cancellation.
- All 20 unsigned branded packages, compiled primary icons, identities, themes, notification-preview PNGs and archive checksums; downloaded packages independently cross-checked.
- Five production-metadata installs: Shopify, Chase, Robinhood, Phantom and Polymarket. Startup and SpringBoard captures confirm their clean scenes and selected names/icons.

The shared Swift suite also passes 47 tests. See `Verification/STATUS.md` and the Actions run for detailed evidence and visual fidelity limits.

## Still requires a signed physical device or additional runtime coverage

- Install and launch the signed IPA on the intended iPhone.
- Confirm foreground, background and locked-device alert delivery, brand name/icon and audio.
- Confirm Focus/Silent mode and denied notification permission behavior.
- Tap a delivered alert and confirm its scene opens.
- Exercise iPad, portrait/landscape, largest accessibility text sizes, VoiceOver, reduced motion and contrast.
- Check signing, provisioning, expiry and refresh requirements for the chosen installation method.

No signed-device test, App Store validation or complete third-party screen parity is claimed.
