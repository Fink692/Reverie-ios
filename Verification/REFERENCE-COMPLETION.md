# Reference-completion pass

This pass implements additional states supported by the saved public references. It also gives those pages working local controls and saved data. It does not establish complete 1:1 appearance or physical-device readiness. No further reference collection is needed to compile, test and review this pass.

## What to review

Use Clean Playback for the bank navigation below. Open the matching scene from Studio or its branded package.

| Scene | Review path and implemented behavior | Evidence |
| --- | --- | --- |
| Chase | Accounts → Plan & track → Budget/Snapshot/Wealth Plan; Benefits → Credit Journey/cards; Invest → account overview/quote. Spending and cash-flow values use local events; savings actions use the existing transfer flow. | Saved bank App Store screenshots |
| Bank of America | Accounts → separate credit/Merrill product; Deals → rewards; Invest → Merrill tabs. Product summaries and per-card locks save separately from checking cash. Payment entry/review/result retain the dated official-guide composition, blue Back/Close/Edit controls and immediate local-payment semantics. | [Payment provenance](../References/Banks/implemented-payment-layout-sources.json) |
| Wells Fargo and other banks | Wells Fargo Explore → product discovery/card offer/LifeSync/Tracker; Barclays Products/Help/debit card; Citi credit-first Accounts/Banking/Services/Quick Lock; Capital One credit-first cards/individual lock confirmation; supported Spending/Help destinations for the remaining themes. Citi/Capital One/BoA product rows have their own saved balance, suffix and optional rewards/payment summaries. Starling virtual Mastercard/Spaces/detail, Monzo Holiday Fund/goal/funding and Revolut appearance/Accounts/detail use bounded reference photos where pictured. | Saved bank App Store screenshots; [photo provenance](../References/Banks/viewport-artwork-sources.json) |
| Wealthsimple | Menu → Chequing/Visa Infinite/Crypto/Security. Chequing actions record local cash movements. Visa freeze/autopay and two-step settings save. Interest, credit and cashback summaries use separate account state; no pending requests or card purchases are invented. Crypto includes the pictured staking overview. | [Account provenance](../References/Markets/account-reference-provenance.json) |
| Coinbase and Robinhood | Coinbase menu → Advanced trade/Rewards/Security. Advanced supports pairs, chart modes/intervals and Orders/Trades; buy/sell opens the authoritative trade ticket. Rewards → Buy USDC; Security saves its two-step setting. Robinhood menu → Cash shows lifetime earnings categories and local add/withdraw/activity. | [Account provenance](../References/Markets/account-reference-provenance.json) |
| MetaMask and Phantom | MetaMask Money → estimated mUSD earnings/Card/Activity, with mUSD in new profiles; transfer-request confirmation follows reference 7. Phantom Trade → Featured/Top Gainers/ranking, asset selection, swap review/confirmation; Top Volume shows missing data. Explore has the pictured token/site icons. | [Wallet artwork provenance](../References/Wallets/viewport-artwork-sources.json) |
| Trust Wallet | Crypto/NFT/rewards; Buy/keypad and Swap; staking list; Connections → request/connect/disconnect; Security alert. Saved holdings drive transfers and swaps; connection choices are local. NFT details show only the pictured artwork fragments. | [Wallet artwork provenance](../References/Wallets/viewport-artwork-sources.json) |
| Polymarket US | Home/Live → Build a Combo → select 2–8 distinct legs → quote/review/buy → portfolio/detail/history. Squads → join/open → local post/reaction/invite. Tennis → set/point/rank data, chart ranges, chat and single-outcome ticket. Combo cash debit and purchase snapshots persist. | `polymarket-4/5/7.jpg`; [additional artwork](../References/Prediction/expanded-artwork-sources.json) |
| Shopify | Orders → create a catalog order → itemized detail → Fulfill items; edit a catalog product and verify the saved order retains its title/price/quantity. Products → inventory quantity card → review/save. Notifications → configure/save/reload/queue/cancel a cue for the selected commerce scene without changing totals. | [Layout provenance](../References/Shopify/implemented-layout-sources.json) |

## Verification

| Check | Current pass |
| --- | --- |
| Shared Swift model suite | 61 passed; zero failures (2026-10-13 20:24:38 UTC) |
| Apple compilation and native unit/UI suite | **PENDING** |
| New route screenshots and visual review | **PENDING** |
| Production startup captures and branded-package checks | **PENDING** |

The earlier [native run 38444892650](https://github.com/Fink692/Reverie-ios/actions/runs/38444892650) belongs to application commit `2c8d82c247f9a6a7cd55c82fededd2ab03148fe2`. Its 137 passing tests, 20 package/startup checks and 25-pair gallery are historical evidence for that commit. They do not validate the new pages, artwork or saved-state changes. [STATUS.md](STATUS.md) holds the final native receipts when available.

The notification catalog now has 34 styles and 36 editable templates, including the reference-backed Capital One notice **Were you double charged?**: `You were charged $10.50 twice today by Camera Supply Store. Tap for details.` [Source](../References/Notifications/duplicate-charge-source.json). Scheduling this notice creates no cash debit or card charge. Custom fields and repeats retain the existing limits: 1–20 alerts, 2-second–24-hour delay, 5–3,600-second interval, and 60 queued alerts per installed app. Delivered appearance/audio remains pending device verification.

## Fidelity boundaries

All balances, orders, transfers, settings, posts and trades remain fictional and local. Security toggles do not enable real account authentication. Cards, rewards and interest do not issue cards, accrue funds or execute staking; combo potential payout is not settlement. Squads/chat lasts for the current playback session, invites remain local and the Tennis footage is visibly paused. There is no banking authorization, exchange networking or live external streaming.

New-profile seeds supply pictured holdings/account summaries/mUSD without replacing existing saved holdings or transactions. Legacy portfolio archives default new financial amounts to zero and the chequing interest rate to 2%; they do not receive the new Wealthsimple 2.25% seed. Bank products are separate summaries, not checking cash. Shopify item snapshots survive catalog edits/deletion; aggregate legacy orders retain a Custom order row. Product photos remain local symbols, and no shipping fee or address is invented.

Bank photo viewports preserve the original low-resolution JPEG/PNG bytes and expose only the cited photo fragments. Decorative wallet and prediction viewports use unchanged original JPEG bytes; SwiftUI clips only the pictured regions during layout. Full screenshot account UI is not used as a playback background. Trust's NFT references end after the top 126 pixels of two artworks, so unseen portions remain unavailable. Public-source provenance does not assert an open license.

Promotional compositions and dated guides do not establish a current authenticated app build. Native illustrated cards, charts, coins, security/rewards art and unpictured action sheets retain differences. Coinbase Card/separate Wallet, full bank/brokerage products, Monzo Flex, exact camera deposit, unseen Benefits/apply/support states, the Polymarket gold one-tap ticket, international parity and exact wallet transaction transitions remain outside the match. Bank Spaces/Joint/Salary presentations retain the existing checking/savings model rather than separate account ledgers. Shopify's sound is the existing cash-register approximation; genuine Cha-Ching audio and delivered notification geometry remain unverified.

[VISUAL-COVERAGE.md](VISUAL-COVERAGE.md) lists supported and unpictured states. [MATCHING-INPUTS.md](MATCHING-INPUTS.md) specifies the target-version recordings needed to extend exact matching. Physical installation, locked-device alerts/audio and Apple distribution signing still require device verification.
