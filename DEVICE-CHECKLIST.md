# Runtime and device verification

## Executed on hosted macOS

- Physical-device Apple SDK compilation without signing.
- Native model/storage/Store XCTest cases.
- iPhone simulator onboarding, scene editing, accounting, persistence and notification queue scheduling/cancellation.
- Immersive commerce Home, Orders, product editing and order fulfillment.
- All 12 bank themes, account navigation, clean playback and branded relaunch/reset (native baseline).
- Native commerce and bank screenshots inspected against public references.

The expanded build checks all 12 bank themes and seven investing/wallet/prediction styles, purchase/send/relaunch flows, all 20 packaged app identities/icons, and five production-metadata startup screens. See `Verification/STATUS.md` and the Actions run for exact results.

## Still requires a signed physical device or additional runtime coverage

- Install and launch the signed IPA on the intended iPhone.
- Confirm foreground, background and locked-device alert delivery, brand name/icon and audio.
- Confirm Focus/Silent mode and denied notification permission behavior.
- Tap a delivered alert and confirm its scene opens.
- Exercise iPad, portrait/landscape, largest accessibility text sizes, VoiceOver, reduced motion and contrast.
- Check signing, provisioning, expiry and refresh requirements for the chosen installation method.

No signed-device test, App Store validation or complete third-party screen parity is claimed.
