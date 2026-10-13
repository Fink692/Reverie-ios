# Runtime and device verification

The hosted checks below passed in [native run 38444892650](https://github.com/Fink692/Reverie-ios/actions/runs/38444892650), application commit `2c8d82c247f9a6a7cd55c82fededd2ab03148fe2`. Downloaded-package and startup receipts are linked below.

## Hosted macOS verification

- Physical-device Apple SDK compilation without signing.
- 71 native model/storage/Store XCTest cases and 19 UI tests, with zero failures; the shared Swift suite adds 47 tests (137 total).
- iPhone Simulator onboarding, scene editing, accounting, persistence and accepted notification queue scheduling/cancellation.
- Immersive commerce Home, Orders, product editing and order fulfillment.
- All 12 bank themes, account navigation, clean playback and branded relaunch/reset.
- Chase and Bank of America payment overdraft rejection, review/edit, receipt, one committed payment and relaunch persistence.
- All seven investing/wallet/prediction home styles, Robinhood purchase/relaunch, MetaMask send/history/relaunch and Polymarket market navigation/trading.
- Customized Shopify cue save/relaunch, accepted system-queue title/body and cancellation. Order number 2088 is saved/reloaded; it is absent from the tested plain new-order body.
- Trust Wallet token search, Crypto/NFT tabs and collectible navigation, with balances preserved.
- 20 unsigned branded packages: native identity/icon/resource checks and independent downloaded-package checks recorded in [final-package-checks.json](Verification/final-package-checks.json).
- 20 production-metadata startup results, with accepted nonblank captures and image hashes in [startup-readiness-checks.json](Verification/startup-readiness-checks.json). All final startup and SpringBoard originals were visually reviewed, including Bank of America and Starling after the 44-point header fix.

See [Verification/STATUS.md](Verification/STATUS.md) for evidence, final environment values and completed review results. Native testing and nonblank captures do not establish complete visual parity.

## Physical device and remaining runtime checks

- Sign, install and launch the IPA on the intended iPhone.
- Confirm foreground, background and locked-device alert delivery, configured name/icon, body layout and audio.
- Confirm Focus/Silent mode and denied notification permission behavior.
- Tap a delivered alert and confirm its scene opens.
- Exercise iPad, portrait/landscape, largest accessibility text sizes, VoiceOver, reduced motion and contrast.
- Check signing, provisioning, expiry and refresh requirements for the chosen installation method.
- Compare the selected target app versions, devices and authenticated states using the inputs in [MATCHING-INPUTS.md](Verification/MATCHING-INPUTS.md).

No signed-device test, App Store validation, genuine Shopify audio or complete third-party screen parity is claimed. Notifications use the installed build’s identity; financial scenes and transactions are fictional and local.
