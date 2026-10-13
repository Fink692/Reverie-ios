# Verification status

The next precision revision is awaiting Apple verification. It refines bank, investing, wallet, commerce and prediction layouts; seeds seven Wealthsimple reference holdings only for new profiles; and adds Chase/Bank of America payment review/commit/relaunch UI coverage. Results below remain the previously verified native baseline until the new hosted run completes.

The fidelity revision passes its native build, all 136 tests, and independent checks of all 20 branded packages. Complete 1:1 parity is not established. The remaining visible differences and missing reference states are recorded in [VISUAL-COVERAGE.md](VISUAL-COVERAGE.md).

Repository: https://github.com/Fink692/Reverie-ios. Native build: [38411196377](https://github.com/Fink692/Reverie-ios/actions/runs/38411196377), commit `261945d1a99a7828d8dc551467ccf2819fc12f94`. Application source and artwork are unchanged in subsequent verification/documentation commits. The readiness harness was verified separately on commit `5b5c752481ac50639ba0a0fb036b75306e62908e`.

| Check | Result |
| --- | --- |
| Shared Swift logic | 47 tests, zero failures |
| Native model, persistence, and Store unit tests | 71 tests, zero failures |
| Native iPhone Simulator UI flows | 18 tests, zero failures |
| Unsigned physical-device compilation | Passed |
| Branded IPA identity, icon, resources, and checksum checks | All 20 passed |
| Independent downloaded IPA validation | All 20 passed |
| Production-metadata install and SpringBoard presentation | All 20 installed; all 20 names/icons visually reviewed |
| Production startup readiness recheck | All 20 passed using the unchanged archived executable |

The UI suite covers all 12 bank themes, commerce navigation, seven investing/wallet/prediction homes, trading and transfer persistence, and customized Shopify cue save/relaunch/system-queue/cancellation. The new Trust Wallet flow verifies token search, Crypto/NFT tabs, collectible navigation and unchanged balances. The customized Shopify payload includes its title, amount, customer, item count, order information, and timing. Scheduled alerts preserve accounting totals.

All branded packages share the exact compiled executable, libraries, and icon catalog. Each has its own bundle identifier, display name, playback metadata, selected compiled primary icon for iPhone and iPad, and notification-preview PNG matching the official source bytes. Independent ZIP CRC, SHA-256, size, metadata, native icon-rendition and resource checks passed for all 20. Every resource except the variant metadata and selected preview PNG matches the base app byte-for-byte. The arm64 executable targets iOS 17, uses SDK 18.5, and contains no code signature. Evidence is in [final-package-checks.json](final-package-checks.json). The base Reverie IPA is included separately.

The production checks use installed Info.plist metadata rather than UI-test brand overrides. All 20 original SpringBoard captures were visually reviewed for the configured names/icons. The first Shopify image from the native run was blank after five seconds; its interactive commerce screenshots and UI tests passed. The capture-only [readiness recheck, run 38418631787](https://github.com/Fink692/Reverie-ios/actions/runs/38418631787), reuses the exact archived executable, debug libraries and asset catalog, with matching SHA-256 values. Shopify's first frame was rejected as uniformly white; the second frame rendered seven seconds later. The other 19 variants passed on their first capture. All 20 accepted startup and SpringBoard captures are preserved; visual review confirms the expected clean startup scenes. The archived simulator app also retains two XCTest support libraries from the native test build. Application executable, debug-library, catalog and configuration checks match the earlier run; details and image hashes are in [startup-readiness-checks.json](startup-readiness-checks.json). This resolves premature screenshot acceptance without changing the application. The checker detects blank content; it does not certify correct screen semantics or visual parity.

Environment: Xcode 16.4 (16F6), iPhoneOS/iPhoneSimulator 18.5 SDK (22F76), deployment target iOS 17. Native runtime: iPhone 17 Pro Max Simulator running iOS 26.2. Native compiler: Swift 6.1.2. Shared compiler: official Swift 6.0.3 Linux. The included Xcode project was generated with official XcodeGen 2.46.0.

The app provides 20 reference styles, 33 notification styles, and 35 editable templates. Playback screens hide Studio chrome and DEMO labels. The visual revision adds individual bank headers and account layouts, Wealthsimple Holdings, Robinhood discovery/Crypto controls, Coinbase layout refinements, Trust Wallet search/rewards/NFT/receive states, Phantom and MetaMask refinements, Shopify chart/order spacing, and Polymarket public sports artwork. These changes improve resemblance to pictured public states. Artwork, secondary navigation, sample account products and unpictured flows still differ; tests do not establish visual equivalence to complete current apps.

Physical iPhone installation, locked-device notification delivery/audio, iPad runtime, a full VoiceOver audit, and Apple distribution signing remain unverified. The IPAs require Apple signing and provisioning before installation. Exact genuine installed display-name values and the Shopify Cha-Ching recording are unverified; commerce uses an original cash-register approximation. All scenes and transactions are fictional and local.
