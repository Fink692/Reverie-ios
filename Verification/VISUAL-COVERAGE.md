# Visual reference coverage

The comparison baseline is the official public seller screenshots preserved under `References`. The catalog includes 161 App Store screenshots: 103 banks, 22 investing, 21 wallets, eight Polymarket, and seven Shopify, plus Shopify mobile website references. Fifty-two additional bank screenshots were recovered from the saved listing URLs on 13 October 2026; their URLs and byte hashes are in `References/Banks/expanded-image-sources.json`.

These are promotional compositions with crops, rotated phones, overlays, and differing capture devices. Some Chase and Bank of America shots visibly use 2021–2023 account dates and older notched devices despite current listing versions. A listing's release date does not establish its screenshot capture version. The screenshots establish the pictured layouts; they do not establish complete current authenticated apps.

The current revision has 136 passing functional tests: 47 shared Swift tests, 71 native unit tests, and 18 iPhone Simulator UI tests in [run 38411196377](https://github.com/Fink692/Reverie-ios/actions/runs/38411196377). All 20 branded package/icon checks passed. These results verify behavior and packaging, not 1:1 appearance. The capture-only [readiness recheck](https://github.com/Fink692/Reverie-ios/actions/runs/38418631787) preserves nonblank production startup images for all 20 styles using the unchanged verified executable. Shopify required a second capture; the other 19 passed on their first attempt. These images remain comparison evidence, not a certificate of exact parity.

## Implemented changes and visible gaps

- **Shopify:** Home/Pulse, chart, Orders controls, and toolbar spacing follow the cited merchant references more closely. Products/Menu, order actions, and settings retain local layouts; the genuine order sound is unverified.
- **Twelve banks:** Individual native home headers replace common brand chrome. Chase amount entry and card locking use the newly recovered references. Account detail, most payment/confirmation screens, and statements remain shared local flows. Photographic backgrounds and product/card artwork are simplified. Navigation also differs: Chase has Cards/More where its pictured home shows Benefits/Invest; Bank of America omits Deals; Wells Fargo has Cards where the reference shows Explore.
- **Robinhood:** A selectable Crypto account uses the supported chart/range composition, including LIVE and YTD; Discover uses the pictured pills/cards/movers. The initial screen remains Investing, while the closest balance reference depicts Crypto. Ordinary stock tickets and unsupported cash, retirement, advanced-trading, and managed-account routes are not reproduced completely.
- **Wealthsimple:** Holdings is now the initial route, with category pills, rows, and the floating navigation capsule. The default local state has three holdings versus seven pictured reference rows; asset artwork and currency formatting still differ. Chequing, Visa, staking, and security references do not have complete matching routes.
- **Coinbase:** Home dividers, shortcuts, balance/chart controls, and the successful-trade composition were refined against the public screenshots. Asset content remains fictional; ordinary trade input, transfer details, rewards, security, and advanced-trading states are not established as matching.
- **Wallets:** Trust adds working search, utility actions, a rewards banner, and Crypto/NFT controls with original artwork. Phantom uses an original circular avatar and refined cash/token glyphs. MetaMask retains a USDC/USDT-derived balance card where its pictured Money card uses mUSD. These artwork/content differences remain, and public references do not establish exact send/history/confirmation flows.
- **Polymarket US:** Twelve downloaded public league/team/season emblems and helmet/football assets replace the corresponding placeholders. The sports Home structure is closer to the pictured reference, but artwork, content, spacing, and market coverage are not wholly identical. Combo trading, chat, livestreams, and the international product are not complete matching implementations.

## Reference state coverage

| Style | Publicly visible states | States not established by these references |
| --- | --- | --- |
| Shopify | Home/Pulse, analytics, orders, partial order detail, quick sale, inventory | Full Products/Menu, merchant settings, fulfillment transitions, delivered notifications/audio |
| Chase US | Accounts composite, investment quote, budget, Zelle amount, check camera, card lock, insights | Ordinary account detail, complete payment confirmations/errors |
| Bank of America US | Accounts, Erica, payments overview, Zelle landing, check deposit, wire landing, rewards, Merrill balance | Payment amount/confirmation, card controls, complete activity details |
| Wells Fargo US | Accounts, Fargo spending, goals, bill pay, Zelle landing, product discovery, stock order review, check deposit | Ordinary checking detail and payment confirmation |
| Citi US | My Citi, credit card, Quick Lock, purchase details, check camera, ATM search, FICO, product discovery | Checking history and ordinary payment entry/confirmation |
| Capital One US | Account overview, Face ID prompt, duplicate-charge alert, lock confirmation, rewards redemption, check camera | Payments, deposit entry, account history |
| HSBC UK | Home, payees/payment landing, future payments, cards/PIN, balance forecast, cheque deposit, chat | Filled payment tickets and final confirmations |
| Barclays UK | Home, account detail, card controls, recipient selection, statements, products/help | Payment amount and confirmation |
| Lloyds UK | Everyday, savings/investments, credit, upcoming payments, PIN, notification settings, activity, chat | Ordinary payment entry/confirmation and account variants |
| NatWest UK | Accounts, widgets, spending, credit score, cards, pots, travel account, appearance | Payment tickets, transaction details, control transitions |
| Monzo UK | Personal home, savings pot, security, Flex, joint-account glimpses | Ordinary send/card controls and actual notification geometry |
| Revolut UK | Savings/joint/salary account compositions, security, stocks/crypto, payment chat, card customization | Ordinary send input/confirmation and receive states |
| Starling UK | Home, Spaces, spending, Space detail, cards, chat | Payment input/confirmation and complete card controls |
| Robinhood | Crypto account, discovery, advanced trading, managed investing, cash/retirement promotions | Complete brokerage Home and ordinary buy/sell tickets |
| Wealthsimple | Holdings, Chequing, Crypto, Visa/security compositions | Complete net-worth Home and ordinary stock order tickets |
| Coinbase | Home, balance, successful trade, advanced trading, rewards/security | Ordinary trade input and send/receive details |
| MetaMask | Home, swap, transfer request confirmation, Money/card/trading compositions | Send-address entry, receive QR, completed transfer |
| Phantom | Home/token list, Trade, Explore | Send, receive, history, completed transfers |
| Trust Wallet | Home/NFT, receive asset list, swap, buy/keypad, staking, connection/risk | Complete history, transfer confirmation, chain-specific states |
| Polymarket US | Sports Home, combo ticket, Squads/chat, live match/chart | Standard single Yes/No ticket, portfolio/history, international app parity |

The app retains fictional local data and transactions. Where references omit a state, that state's interaction remains an original local flow. Native tests verify those controls, persistence and accounting; they do not certify visual equivalence.

## Exact comparison requirements

Exact 1:1 verification requires unaltered screenshots or screen recordings from the target app version/build, country, iPhone model, iOS version, appearance, account/product type, and required states. Notification comparisons also need actual title/body examples and a legitimate audio reference where a matching sound is required. The current evidence supports Shopify's example order body and Capital One's example duplicate-charge wording; other templates remain editable approximations.
