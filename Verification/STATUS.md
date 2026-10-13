# Verification status

- Repository: https://github.com/Fink692/Reverie-ios, public, Actions enabled.
- Shared expanded Swift logic: official Swift 6.0.3 Linux compiler, **41 tests passed, zero failures**. Raw output: `core-tests.txt`.
- Latest native bank/commerce baseline: [38347429865](https://github.com/Fink692/Reverie-ios/actions/runs/38347429865), commit `773e097`. Physical-device compilation, unsigned base IPA packaging, native unit/UI step, screenshot export, and simulator launch passed. The suite contains 47 unit tests and 12 UI tests; final logs and 13 baseline variant packages are still being collected.
- Expanded native build: pending. Investing, wallet, and prediction files pass Swift frontend syntax parsing. Apple SDK typechecking and native transactions/navigation are not yet verified for these additions.
- Catalog: 20 reference styles and icons: Shopify, 12 banks, Robinhood, Wealthsimple, Coinbase, MetaMask, Phantom, Trust Wallet, and Polymarket. Metadata and generated-plist validation pass. Actual expanded IPA builds and five production-metadata startup checks are pending.
- Native baseline environment: Xcode 16.4; iPhone 17 Pro Max simulator running iOS 26.2.
- Actual baseline screenshots: commerce Home/Orders, all 12 bank overviews, clean commerce/banking, and related navigation. Public design references and known differences are documented in `References`.
- Xcode project: generated with official XcodeGen 2.46.0; checked-in project includes all 12 app Swift files and seven unit-test files and opens without requiring the generator.
- Physical iPhone installation, locked-device notification presentation/audio, iPad runtime, complete VoiceOver audit, and Apple distribution signing: **not verified**. Unsigned IPA packages require signing before installation.

All scenes are local fictional roleplay flows. Complete authenticated third-party screen coverage and pixel-identical parity are not certified. Brand artwork uses official public Apple listings; genuine installed display-name values and exact Shopify Cha-Ching audio remain unverified. Wallets never request recovery phrases/private keys or submit blockchain transactions.
