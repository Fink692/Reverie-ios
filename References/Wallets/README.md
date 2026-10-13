# Crypto wallet iPhone references

Retrieved 2026-10-13 from the actual wallet sellers' public Apple App Store listings. Raw individual listing results are saved in `<id>.json`; `<id>-image-sources.json` maps each downloaded screenshot to its exact public Apple CDN URL, dimensions, local path, and SHA-256. URLs were restricted to HTTPS `mzstatic.com` hosts. The full screenshots are reference material. A small set is also bundled as unchanged original bytes solely for bounded decorative-art viewports; those uses are recorded in `viewport-artwork-sources.json`. The app never displays a complete screenshot as its interface.

| Theme | Official listing | Seller | Listed version | Listed release |
| --- | --- | --- | --- | --- |
| MetaMask | [MetaMask: Trade Crypto](https://apps.apple.com/us/app/metamask-trade-crypto/id1438144202) | ConsenSys AG | 8.13.0 | 2026-09-29 |
| Phantom | [Phantom: Trading Wallet](https://apps.apple.com/us/app/phantom-trading-wallet/id1598432977) | Phantom Technologies Incorporated | 26.32.0 | 2026-10-07 |
| Trust Wallet | [Trust: Crypto & Bitcoin Wallet](https://apps.apple.com/us/app/trust-crypto-bitcoin-wallet/id1288339409) | DApps Platform Software Services Ltd. | 26.41.11 | 2026-10-10 |

All three screenshot sets were viewed as contact sheets. `metamask-2.jpg`, `phantom-1.jpg`, and `trustWallet-4.jpg` were additionally inspected full size. Phone hardware, giant floating logos/coins, promotional headlines, gradient backdrops, and decorative hands are outside the native application UI.

## MetaMask

- `metamask-2.jpg`: current listing home composition. Almost-black surface, Account 1 dropdown left, history/copy/menu symbols right. Large white balance left and lime positive change. Four dark rounded rectangular Buy/Swap/Send/Receive actions. Money balance card and Tokens list. Native bottom tabs are Home, Explore, a blue central plus/Trade button, Money, Rewards.
- The large fox overlapping the balance at the right is a promotional overlay; it extends beyond the device screen.
- `metamask-6.jpg`: dark Swap route with amount/token cards stacked vertically (ETH to USDC), compact quote/fee information and a wide white Swap button at the bottom.
- `metamask-7.jpg`: dark transfer request confirmation with token amount, security information, and bottom Cancel/Transfer controls. It is not evidence for the send-address entry screen.
- Other references show Money, perpetual trading, Predictions, tokenized assets, and the MetaMask card.

## Phantom

- `phantom-1.jpg`: black home with avatar and top Home/Trade/Explore pill navigation. Selected Home pill is lavender; inactive pills are dark. My Wallet dropdown, large white left-aligned balance, green Today gain, a rounded cash row, and Tokens section. Token rows are separate very dark rounded cards with icon/name/quantity left and value/change right.
- `phantom-2.jpg`: expanded token list using the same dark rounded-row treatment.
- `phantom-3.jpg`: Trade tab with stacked You Pay/You Receive panels and a small lavender swap-direction control. Token rankings below.
- `phantom-4.jpg`: Explore tab with filter pills and token/site discovery.

No send-address entry, receive QR, or completed-transfer screenshot is supplied in this public set. The native top tab layout is visible; a hypothetical bottom tab bar is not supported by these images.

## Trust Wallet

- `trustWallet-4.jpg`: white Home screen with gray gear left and bell right, a pale search field, Main wallet dropdown and dark balance. Gray circular Send/Receive/Buy/Sell/History actions. Promotional rewards banner in the content, then Crypto/NFT tabs and NFT grid. The giant poster title is not native app typography.
- `trustWallet-5.jpg`: white Receive asset list with search, network filter and token rows.
- `trustWallet-3.jpg`: light Swap screen with stacked You Pay/You Get panels, token selectors, rate text and pale bottom action.
- `trustWallet-2.jpg`: Buy BTC screen with large amount, provider row and numeric keypad.
- Other images show native staking, connection confirmation and a risk warning.

The public listing uses an older iPhone physical frame in this marketing artwork. That does not establish the screenshot's capture date or prove that every current Trust Wallet route still matches it.

## Implemented token artwork

The app uses unchanged Bitcoin, Ethereum, Solana and USDC PNG files from the public Trust Wallet assets repository at immutable revision `d541ca5c51609e24966712403e10a4b438c47982`. [implemented-artwork-sources.json](implemented-artwork-sources.json) records the exact download URLs, byte counts, dimensions and SHA-256 values. The gray Ethereum asset is used by Phantom; MetaMask and Trust Wallet use a separately drawn white Ethereum diamond on the blue circular background shown in their references. These token files provide artwork provenance, not proof of complete wallet UI parity.

The Phantom account avatar, Trust rewards chest, connection/risk illustrations, staking/provider icons, Phantom discovery icons and MetaMask card now use bounded SwiftUI viewports of unchanged original public listing JPEG bytes. [viewport-artwork-sources.json](viewport-artwork-sources.json) records the complete source file hashes, dimensions and each visible source rectangle. No image files are edited or generated, and surrounding screenshot UI and balances are excluded from these viewports.

The Trust NFT listing ends after the top 126 source pixels of two artworks. Those two fragments are displayed at their actual visible aspect ratio; unseen artwork is not invented. NFT titles and collection details remain fictional. Home and Receive rows preserve saved assets and quantities. Phantom Trade and MetaMask swap/confirmation continue to use saved holding prices and balances, including actual zero-fee local math. Phantom discovery prices/market caps and Trust staking APR retain the frozen values visibly established by their listing references; they never update wallet quotes. Trust Buy displays the pictured provider identity while its local confirmation spends the saved stablecoin balance; the fiat entry is divided by that saved funding token price before any swap. The MetaMask Money page uses the pictured 4% APY to calculate estimated earnings from saved mUSD value without crediting earnings or changing funds.

## Fidelity limits

These references support visible compositions only. They do not establish exact installed app display names, hidden screens, input states, keyboard behavior, recovery/import flows, signing confirmations, chain-specific UI, current notification sounds, or every latest-binary interaction. Custom local send/receive/history functionality must not be described as an exact reproduction of states not shown here. The local roleplay app does not need seed phrases, private keys, live wallet imports, or live-chain operations to implement these scenes.
