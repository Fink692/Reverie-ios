# Investing and exchange iPhone references

Retrieved 2026-10-13 from each seller's public Apple App Store listing. `robinhood.json`, `wealthsimple.json`, and `coinbase.json` preserve the individual listing results returned by Apple's public search API. Each `<id>-image-sources.json` preserves the exact Apple CDN URL, local image path, dimensions, and SHA-256 for every screenshot. Image URLs were restricted to HTTPS `mzstatic.com` hosts. Images are research references, not application assets.

| Theme | Official listing | Seller | Listed version | Listed release |
| --- | --- | --- | --- | --- |
| Robinhood | [Robinhood: Trading & Investing](https://apps.apple.com/us/app/robinhood-trading-investing/id938003185) | Robinhood Markets Inc | 2026.41.0 | 2026-10-12 |
| Wealthsimple | [Wealthsimple](https://apps.apple.com/ca/app/wealthsimple/id1403491709) | Wealthsimple Financial Inc. | 2.247.0 | 2026-10-10 |
| Coinbase | [Coinbase: Buy Crypto & Stocks](https://apps.apple.com/us/app/coinbase-buy-crypto-stocks/id886427730) | Coinbase, Inc. | 14.39.44 | 2026-10-12 |

All screenshot sets were visually inspected using contact sheets. `robinhood-4.jpg`, `wealthsimple-2.jpg`, and `coinbase-2.jpg` were additionally inspected full size. Each screenshot is a promotional App Store composition; phone frames, headline copy, backgrounds, and enlarged overlays are not native app chrome.

## Robinhood

- `robinhood-4.jpg`: dark crypto dashboard. White left-aligned title and balance, vivid lime positive change, unfilled lime line graph on black, horizontal LIVE/1D/1W/1M/3M/YTD/1Y range controls. Selected range has a lime rounded background with black text. This is a crypto account screen, not evidence for the complete brokerage home.
- `robinhood-1.jpg`: dark discovery/search route with top search field, category pills, market index tiles with tiny lime charts, and top movers.
- `robinhood-7.jpg`: dark advanced trading route with candlesticks and small chart controls. It does not expose the ordinary trade-confirmation sheet.
- `robinhood-8.jpg`: managed-investing account with balance and purple allocation ring.
- Other references show cash earnings, event predictions, retirement contributions, 24 Hour Market, and support chat.

Use black surfaces, restrained gray separators, white primary typography, and lime chart/range accents for the directly supported routes. Do not infer that every app screen uses the same chart or action arrangement.

## Wealthsimple

- `wealthsimple-2.jpg`: light Holdings list. Small centered title; horizontally scrolling rounded category pills for Stocks, ETFs, Crypto, CAD, USD; rows with square asset icons and ticker/quantity on the left, value and red/green change on the right. Thin gray row separators. Floating white bottom capsule with four symbols: home, search, transfers, activity/history.
- `wealthsimple-3.jpg`: Chequing route with balance, interest card, four actions, requests, and activity.
- `wealthsimple-5.jpg`: Crypto route with an informational banner, staking section, and holdings rows.
- `wealthsimple-4.jpg`: Visa Infinite card overview; `wealthsimple-6.jpg`: account security presentation. `wealthsimple-1.jpg` is a giveaway promotion, not the normal home.

The serif headlines belong to the promotional poster, not the Holdings screen. The native Holdings screen uses a simple sans-serif font. The screenshot set does not provide a complete net-worth home or ordinary stock order ticket.

## Coinbase

- `coinbase-2.jpg`: white/light home panel. App-grid symbol left, rounded search field center, bell right. Balance is left-aligned with a small blue sparkline on the right. Four blue circular Buy/Send/Receive/Scan buttons. Secondary Card/Rewards/Coinbase Wallet/Advanced trade shortcut row. Prices section uses asset rows, compact colored sparklines, right-aligned prices, and green percentage gains.
- `coinbase-5.jpg`: light balance route with blue chart, time-range controls, and blue circular Add cash/Cash out/Send/Receive actions.
- `coinbase-3.jpg`: successful trade confirmation with a large blue circular check, short success text and amount. Promotional fee information extends beyond the native card and should not be copied as a universal confirmation element.
- `coinbase-7.jpg`: dark advanced BTC-USD candlestick route. This is a separate visual mode, not a reason to make the basic home dark.
- Other references show USDC rewards, security onboarding, and a tilted home composition.

## Fidelity limits

These are the current public listing's screenshots. Their publication dates are not separately supplied, and their appearance is not proof that every image came from the exact current binary version. They do not establish all interactive states, ordinary buy/sell tickets, notification wording/sound, gestures, typography metrics, or device-specific spacing. Treat inferred routes as custom local simulation behavior. Full 1:1 fidelity requires running both apps on matching iPhone/iOS configurations and comparing their screenshots.

## Implemented account routes

The original screenshots for Coinbase Rewards, account security, and advanced trade; Wealthsimple Chequing, Visa Infinite, Crypto, and Security; and Robinhood cash earnings were individually inspected at original detail before implementation. [account-reference-provenance.json](account-reference-provenance.json) maps each native view to its exact retained public Apple CDN URL and SHA-256. Native illustrations are SwiftUI shapes; reference screenshot bytes are unchanged and are not playback assets. The official Wealthsimple credit-card page returned HTTP 403 during an asset check; no artwork was downloaded from that page.

- Coinbase Rewards opens the USDC overview and the existing Buy ticket. An absent USDC asset can be added at zero units without changing funds. The separate advanced route has Candle/Line/Area, interval, indicator, and star controls; its buy/sell buttons use the existing authoritative order flow.
- Wealthsimple's centered account menu now selects Holdings, Chequing, Visa Infinite, Crypto, and Security. Chequing reads available cash and completed cash events; Add/Transfer/e-Transfer/Pay bill use the same cash ledger. Visa summary fields, freeze, and auto-pay use persisted account state. Crypto shows actual saved crypto holdings, available-asset additions, and the referenced staking overview. No staking credits, pending requests, or card transactions are fabricated.
- Security action states and the account summaries persist through the validated portfolio account-state API. Financial account summaries are separate from spendable cash and can be edited under Portfolio settings. Robinhood's cash-earnings view uses persisted high-yield cash and IRA-match totals, while Add/Withdraw and cash activity use the actual cash ledger.

The screenshots expose overview states, not the complete interaction sequences. The transfer and management sheets, security action behavior, and account-state editor are local inferred flows. Exact 1:1 fidelity has not been established by these public promotional references alone.
