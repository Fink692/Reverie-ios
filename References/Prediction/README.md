# Polymarket iPhone references

Retrieved 2026-10-13 from [Polymarket: Trade Live Sports](https://apps.apple.com/us/app/polymarket-trade-live-sports/id6648798962), Apple app ID **6648798962**, seller **Blockratize Inc**, App Store developer **Polymarket**. The listing result reports version **2.8.13**, released **2026-10-10**. `polymarket.json` preserves the listing result. `polymarket-image-sources.json` preserves each exact Apple CDN screenshot URL, local path, dimensions and SHA-256. URLs were restricted to HTTPS `mzstatic.com` hosts.

This is Polymarket's US native app listing. Third-party apps named Polymtrade, Share, and prediction-alert tools were not used as first-party Polymarket references. The public listing does not establish that Polymarket's international web UI has the same layout.

All eight screenshots were visually inspected as a contact sheet; `polymarket-2.jpg` was additionally inspected full size. Marketing photographs, large headlines, tilted phone hardware, payout overlays and referral promotions are not reliable native pixel geometry.

## Visible native UI

- `polymarket-2.jpg`: white sports-first Home. Compact Polymarket wordmark left; blue referral-action button and bell right; horizontal sport/category icons; large rounded season banner; Trending scoreboard cards; Live match list. Native lower navigation includes Home, Live, Portfolio, Squads and Search; selected Home is blue. Portfolio's navigation item can show a dollar balance.
- `polymarket-3.jpg`: promotional collage showing broader event questions and a multiple-outcome chart. It is not a complete native discovery/detail screenshot. The event content supports generic local prediction categories but not an exact standard Yes/No order ticket layout.
- `polymarket-4.jpg`: native combo trade overlay with market legs, a Cost amount, potential payout, and rounded bottom Buy control. The Buy control has a multicolor gradient. This is a combo ticket, not evidence for every single-event order ticket.
- `polymarket-5.jpg`: chat/score-trading area and Squads discovery with an invite card. Match outcome buttons use blue and dark-red fills.
- `polymarket-6.jpg`: full-screen gold live-trade view and amounts. Much of the composition is promotional; it cannot establish universal execution confirmation styling.
- `polymarket-7.jpg`: match livestream above outcome charts, live probabilities and a comment stream. This does not show a standard portfolio or order-history page.
- `polymarket-1.jpg` and `polymarket-8.jpg`: primarily marketing/partnership promotions.

## Design guidance and limits

Use white/light content surfaces, compact dark typography, blue selection/action accents and sport/category navigation for the directly observed Home route. Keep illustrative local event questions and balances customizable. Standard Yes/No market details, order-entry forms, portfolio rows and history can be consistent local simulation routes, but these sources do not justify claiming their exact current Polymarket layout.

The current listing's screenshots are public promotional assets without individual capture dates. They do not verify every current-binary screen, system notification name, notification sound, gestures, keyboard states or precise spacing. App Store listing title is recorded separately from the selected short display label Polymarket; the genuine installed CFBundleDisplayName was not inspected. Exact full-app parity requires a same-device comparison against the target app.


## Implemented public artwork

`implemented-artwork-sources.json` records the exact URLs, filenames, dimensions, byte sizes, SHA-256 hashes and attribution for 12 downloaded public league/team/helmet PNGs used by the native sports views. Downloaded bytes are preserved without transformation. These are proprietary public brand assets; no open-content license is asserted. The banner helmet differs from the specific promotional screenshot helmet. The local single-outcome order ticket remains a simulation-specific form; the pictured combo, Squads/chat and live-match compositions now have separate native routes.


## Expanded native reference routes

Original screenshots `polymarket-4.jpg`, `polymarket-5.jpg`, and `polymarket-7.jpg` were additionally inspected full size before implementing the following routes:

- **Combo**: Home/Live has a Build a Combo control. The rounded sheet follows screenshot 4's market-leg hierarchy, Cost / To Win columns, outlined leg markers and multicolor Buy action. A working local selector supports 2–8 distinct current markets and either outcome. Review and confirmation use the store's authoritative atomic combo quote and purchase APIs. Actual cash is debited once; immutable combo positions and history survive a saved-session reload. The potential payout is not credited to cash. The observed screenshot's six promotional example markets are not seeded as fabricated transactions.
- **Squads**: The selected tab opens the screenshot 5 composition with a compact Squads header, large italic metallic wordmark, explanatory copy, invite control, community member row and football cover panels. Join/Open enters a working local chat for the community's league, including score context, message input, quick reactions and current-price trade buttons. Messages, joined state and reactions are confined to the current playback session. Invite codes are local scene presentation and do not award money or contact another person.
- **Live match**: Sports scorecards and match rows open the screenshot 7 composition: match status, scores, red/blue outcome probability chart, All/Game/Live ranges, comment preview, expandable local chat and real local single-market order entry. A new fictional Tennis starter follows the pictured Carlos Alcaraz / Arthur Fils matchup and 67% / 33% probability. Saved older sessions retain their existing games. The original screenshot's tennis footage is a paused reference still with a visible Paused label and hide/show controls; there is no live network stream.

`expanded-artwork-sources.json` records the unchanged public screenshot assets and two additional original public Polymarket Buffalo/Kansas helmet assets, including exact source URLs, byte sizes, dimensions and SHA-256. Screenshot files are bundled byte-for-byte. Native layout clips the tennis court footage and pictured Logan community avatar at runtime, excluding marketing text and device hardware; no image file is cropped, composited, recolored or otherwise edited. These public proprietary assets are not asserted to have an open-content license. The public community name/avatar illustrates the pictured discovery card and is not an identity claim about the user of the local scene.

The visible screenshots remain promotional references, not proof of exact current-binary navigation or universal trade/portfolio styling. Screenshot 6's full-screen gold live-trade composition has not been generalized into a universal order confirmation. Native Apple build and same-device visual comparison are coordinated in the project verification log.
