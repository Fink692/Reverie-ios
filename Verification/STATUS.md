# Verification status

This follow-up reference-completion revision is in progress. Its new account, combo, wallet and commerce flows have not yet passed native Apple compilation or UI tests. The results below describe the previously verified revision, not the current working tree.

The precision revision passes its native build, all 137 tests, and independent checks of all 20 branded packages. All 20 production startup and SpringBoard originals and five additional checkpoints were visually reviewed. Complete 1:1 parity is not established.

Native build: [38444892650](https://github.com/Fink692/Reverie-ios/actions/runs/38444892650), application commit `2c8d82c247f9a6a7cd55c82fededd2ab03148fe2`. Subsequent documentation changes preserve this application source and artwork.

| Check | Result |
| --- | --- |
| Shared Swift logic | 47 tests, zero failures |
| Native model, persistence and Store unit tests | 71 tests, zero failures |
| Native iPhone Simulator UI flows | 19 tests, zero failures |
| Unsigned physical-device compilation | Passed |
| Branded IPA identity, icon, resources and checksum checks | All 20 passed |
| Independent downloaded IPA validation | All 20 passed; [receipt](final-package-checks.json) |
| Production-metadata startup readiness | All 20 passed; [receipt](startup-readiness-checks.json) |
| Visual inspection of final captures | All 20 startup/SpringBoard originals and five checkpoints reviewed |

The functional total is 137 tests. Complete 1:1 parity is not established. [VISUAL-COVERAGE.md](VISUAL-COVERAGE.md) records visible differences and unpictured states; [MATCHING-INPUTS.md](MATCHING-INPUTS.md) identifies the target-version recordings needed for exact comparisons.

## Functional coverage

The UI suite covers all 12 bank themes, commerce navigation, seven investing/wallet/prediction homes, trading and transfer persistence, Trust Wallet search/Crypto/NFT/collectible navigation, and customized Shopify cue save/relaunch/accepted-system-queue/cancellation.

The added Chase and Bank of America payment test rejects an overdraft, enters Jordan Lee and $36.25 with reference Invoice 241, captures review and receipt, verifies that editing review leaves the balance unchanged, commits one payment, verifies the new balance after relaunch, and checks that activity contains one saved payment. The receipt reflects an immediate fictional local payment; the Bank of America tutorial’s scheduled-payment/enrollment process is not implemented.

The Shopify test saves and reloads amount 179.25, title Checkout completed, customer Morgan Hale, quantity 3, order number 2088, a five-minute delay and a thirty-second repeat interval. It then checks the accepted system request title and exact plain new-order body: `[Studio Supply] You have a new order for 3 items totaling $179.25. From Morgan Hale.` The saved order number is not part of that body. Cancelling the queued request clears the queue. These checks establish saved settings and pending requests, not locked-device delivery or authentic notification appearance.

The app provides 20 reference styles, 33 notification styles and 35 editable templates. Styles cover commerce, banking, investing, crypto, predictions, creators and custom text. Wording is shared within categories; no genuine notification-copy equivalence is established separately for every brand. Each session supports 1–20 alerts, delays of 2 seconds to 24 hours, intervals of 5–3,600 seconds, and a maximum of 60 queued alerts per installed app. Scheduling leaves accounting totals unchanged.

## Packages and captures

All branded packages reuse the compiled executable, libraries and asset catalog, with separate bundle identifiers, names, selected primary icons, playback metadata and notification-preview PNGs. The independent receipt records ZIP CRC, SHA-256, sizes, identity, icon renditions and resources for each downloaded package. Public preview images preserve the cited source bytes. The base Reverie IPA is included separately. Unsigned packages require Apple signing and provisioning before physical installation.

Startup verification installs production metadata and checks rendered content before accepting a capture. It rejects uniformly blank screens and retries; this detects premature capture acceptance, not correct screen semantics or pixel equivalence. The receipt records accepted image hashes and attempts for the final run. All 20 startup and SpringBoard originals were reviewed, including the corrected Bank of America and Starling headers. Each startup passed on its first capture. The simulator archive includes two XCTest support libraries; its application executable, debug libraries and catalog match the production startup base exactly. These extra test libraries are recorded separately in the receipt.

The validated comparison gallery contains 25 pairs with 50 unaltered images: 20 startup/reference pairs, Chase and Bank of America review/result checkpoints, and a Trust Wallet NFT checkpoint. A promotional or dated guide reference remains evidence of the pictured composition, not proof of a current authenticated application.

## Precision changes and limits

Fresh Wealthsimple profiles seed the seven fully visible reference holdings; saved profiles are preserved. The revision uses seven public company glyphs, four token images, and 11 dated guide captures with recorded source hashes. It refines individual bank headers, portfolio/wallet controls, Shopify toolbar marks and Polymarket colors/tickets. Chase and Bank of America payment guides support those specific compositions. Other bank product/navigation flows, Coinbase secondary products, Polymarket combos/chat/livestreams and wallet artwork retain material differences.

Playback hides Studio chrome and DEMO labels. All account data and transactions remain fictional and local. Exact installed names, genuine app geometry across versions and all authenticated flows are not verified. Shopify new-order alerts use an original 1.65-second cash-register approximation; the genuine Cha-Ching recording is unverified, and other alerts use default sound.

Physical iPhone installation, foreground/background/locked-device delivery and audio, Focus/Silent-mode behavior, denied-permission behavior on the intended device, delivered-alert routing, iPad runtime, full accessibility coverage and Apple distribution signing remain unverified. [DEVICE-CHECKLIST.md](../DEVICE-CHECKLIST.md) separates executed hosted checks from physical-device work.

Verified native environment: Xcode 16.4 (16F6), iPhoneOS/iPhoneSimulator 18.5 SDK, iOS 17 deployment target, Swift 6.1.2 and iPhone 17 Pro Max Simulator running iOS 26.2. The shared suite uses official Swift 6.0.3 Linux. The included project was generated with official XcodeGen 2.46.0.
