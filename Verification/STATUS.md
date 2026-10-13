# Verification status

- Repository: https://github.com/Fink692/Reverie-ios, public, Actions enabled.
- Shared Swift logic: official Swift 6.0.3 Linux compiler, **33 tests passed, zero failures**. Raw output: `core-tests.txt`.
- Baseline native run: [38337929358](https://github.com/Fink692/Reverie-ios/actions/runs/38337929358), commit `f989f89`, **successful**. Unsigned physical-device Apple SDK compilation, 34 native unit tests and 6 UI tests passed.
- Immersive native run: [38339398539](https://github.com/Fink692/Reverie-ios/actions/runs/38339398539), commit `28c276b`. Unsigned device compilation and IPA packaging passed; **42 native unit tests and 7 of 8 UI tests passed**. One bank UI assertion found the theme menu before it was hittable. The strict wait and 44-point touch target are fixed in the next build.
- Native environment: Xcode 16.4; iPhone 17 Pro Max simulator running iOS 26.2.
- Actual native screenshots: commerce Home and Orders, bank Chase. Reviewed against official references. Rounded panel clipping, localized order IDs and greeting typography corrected after review.
- Pending hosted verification: all 12 bank themes, two branded startup/relaunch flows, original commerce order sound resource, and all 13 unsigned brand packages with verified bundle metadata/icons.
- Xcode project: generated with official XcodeGen 2.46.0; checked-in project opens without requiring the generator.
- Physical iPhone installation, locked-device notification presentation/audio, iPad runtime, complete VoiceOver audit, and Apple distribution signing: **not verified**. Unsigned IPA packages require signing before installation.

The visible scenes are reference-based local roleplay flows. Complete third-party authenticated screen coverage and pixel-identical parity are not certified. Notification artwork is from official public Apple listings; genuine installed display-name values and exact Shopify Cha-Ching audio remain unverified.
