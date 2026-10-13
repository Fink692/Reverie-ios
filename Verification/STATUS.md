# Verification status

Repository: https://github.com/Fink692/Reverie-ios. Native build: [38367881655](https://github.com/Fink692/Reverie-ios/actions/runs/38367881655), commit `dceee7ba9a0f0e16d8c8a2ab49c3ec3d1ac6ffd8`.

| Check | Final result |
| --- | --- |
| Shared Swift logic | 47 tests, zero failures |
| Native model, persistence, and Store unit tests | 71 tests, zero failures |
| Native iPhone Simulator UI flows | 17 tests, zero failures |
| Unsigned physical-device compilation | Passed |
| Branded IPA identity, icon, resources, and checksum checks | All 20 passed |
| Independent downloaded IPA validation | All 20 passed |
| Production-metadata startup | Shopify, Chase, Robinhood, Phantom, and Polymarket installed and captured |

The UI suite covers all 12 bank themes, commerce navigation, seven investing/wallet/prediction homes, trading and transfer persistence, and customized Shopify cue save/relaunch/system-queue/cancellation. The customized payload includes its title, amount, customer, item count, order information, and timing. Scheduled alerts preserve accounting totals.

All branded packages share the exact compiled executable, libraries, and icon catalog. Each has its own bundle identifier, display name, playback metadata, selected compiled primary icon for iPhone and iPad, and notification-preview PNG matching the official source bytes. The manifest records archive sizes and SHA-256 checksums. Independent cross-check evidence is in `final-package-checks.json`. The base Reverie IPA is included separately.

Five production startup checks use installed Info.plist metadata rather than UI-test brand overrides. Each installed bundle is validated before launch. Startup and subsequent SpringBoard screenshots are included in the build evidence; visual review confirms all five selected names/icons on SpringBoard and clean startup screens.

Environment: Xcode 16.4 (16F6), iPhoneOS/iPhoneSimulator 18.5 SDK (22F76), deployment target iOS 17. Native runtime: iPhone 17 Pro Max Simulator running iOS 26.2. Native compiler: Swift 6.1.2. Shared compiler: official Swift 6.0.3 Linux. Xcode project generated with official XcodeGen 2.46.0; all 13 application Swift files and eight unit-test files are included.

The app provides 20 reference styles, 33 notification styles, and 35 editable templates. Actual simulator captures show readable layouts without material clipping or DEMO labels. Phantom and Coinbase closely follow their paired visible references; Polymarket reproduces the sports-first structure with simplified league/team artwork. Trust Wallet omits the reference's rewards/NFT section, and Wealthsimple's exact Home layout has no directly matching reference. Complete authenticated screen coverage and pixel-identical parity are not certified. Reference provenance and other known differences are documented in `References`.

Physical iPhone installation, locked-device notification delivery/audio, iPad runtime, a full VoiceOver audit, and Apple distribution signing remain unverified. The IPAs require Apple signing and provisioning before installation. Exact genuine installed display-name values and the Shopify Cha-Ching recording are unverified; commerce uses an original cash-register approximation. All scenes and transactions are fictional and local.
