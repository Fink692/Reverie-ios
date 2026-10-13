# iPhone banking reference catalog

Retrieved 13 October 2026 from Apple's public App Store lookup service. Each bank's JSON file preserves the official listing metadata and screenshot URLs. The numbered JPG files preserve screenshots supplied by the bank's developer. These are research references; the app renders native SwiftUI views and does not display marketing screenshots as its interface.

All 103 listing screenshots are now preserved. `expanded-image-sources.json` records the URLs, filenames, sizes and SHA-256 hashes for 52 additional screenshots recovered from these saved listing URLs during the fidelity review. Some marketing shots visibly contain older dates/devices; the listing version is not proof of a screenshot's capture version.

The twelve included banks are a concrete selection of major US and UK banks plus Revolut. This selection does not represent every major bank worldwide. A country's own banking app may differ from another country's app with the same brand.

| Appearance | App Store listing | Version observed | Screenshot observations used |
|---|---|---|---|
| Chase US | [Chase Mobile](https://apps.apple.com/us/app/id298867247) | 4.794 | Blue greeting area, white Accounts region, blue bank-account section header, large checking/savings balances. Screenshots 1–2 are angled marketing composites. |
| Bank of America US | [Bank of America Mobile Banking](https://apps.apple.com/us/app/id284847138) | 26.10.02 | White Accounts/Dashboard selector, help search field, greeting/rewards panel, grouped account panels with red/blue accents. Screenshot 1 is the account overview; 2 shows Erica. |
| Wells Fargo US | [Wells Fargo Mobile](https://apps.apple.com/us/app/id311548709) | 26.09.02 | Warm pale home background, greeting, Fargo search, white rounded checking and savings cards, dark text with red identity. Screenshot 2 shows the account overview. |
| Citi US | [Citi Mobile](https://apps.apple.com/us/app/id301724680) | 9.99.0 | Blue gradient overview, white account text, translucent account cards, compact shortcut buttons, a white transaction region. Screenshot 1 shows My Citi; 2 shows a credit-card view. |
| Capital One US | [Capital One Mobile](https://apps.apple.com/us/app/id407558537) | 6.55.1 | Centered greeting with Pay now link, stacked colored account tiles with large balances, slim white separators. Screenshot 2 is an angled account overview; 6 shows card locking. |
| HSBC UK | [HSBC UK Mobile Banking](https://apps.apple.com/gb/app/id1220329065) | 3.74.31 | White top Home/Pay/Cards/Invest menu, circular shortcuts, Your products heading, flat white product cards with red HSBC symbols. Screenshots 1, 2, and 4 show home, payments, and cards. |
| Barclays UK | [Barclays](https://apps.apple.com/gb/app/id536248734) | 3.76.2 | Large Home heading, name and search, Your accounts row, white account tile with a cyan miniature card, Pay/Card actions. Screenshots 1, 3, 5, and 6 show home, detail, cards, and payments. |
| Lloyds UK | [Lloyds Mobile Banking](https://apps.apple.com/gb/app/id469964520) | 194.05 | Light gray home, horizontal Summary/Everyday/Save & Invest spaces, selected black pill, current-account card, Pay & transfer and Regular payments actions. Screenshot 1 shows Everyday. |
| NatWest UK | [NatWest Mobile Banking](https://apps.apple.com/gb/app/id334855322) | 7.71.0 | Purple Personal selector on pale home, white current-account card, account details and right-aligned balance, stacked savings accounts. Screenshot 1 shows the account overview. |
| Monzo UK | [Monzo Bank](https://apps.apple.com/gb/app/id1052238659) | 8.4.0 | White home header, bright coral account panel with balance at right, Add money/Card actions, white Activity list with merchant icons and green incoming amounts. Screenshot 1 is the personal home. |
| Revolut UK | [Revolut](https://apps.apple.com/gb/app/id932493382) | 10.151 | Centered large balance over a dark/image-backed account surface, Accounts pill, four circular Add money/Move/Info/More actions, rounded dark transaction tiles. Screenshots 2, 4, and 8 show account variants. |
| Starling UK | [Starling Mobile Banking](https://apps.apple.com/gb/app/id956806430) | 4.70.0 | Teal balance header with Personal selector, In Spaces/Total balance summaries, white rounded transaction surface, Search & filter and lower navigation. Screenshot 1 shows the main account; 2 shows Spaces. |

## How the references map to the code

`Sources/BankPlayback.swift` has an individual home composition for every listed bank. The reference establishes visible hierarchy, spacing relationships, dominant colors, grouping, and action wording. Native controls supply accessible touch targets, iPhone safe-area behavior, transaction navigation, keyboard handling, and local state changes.

Use the title menu or More tab to select a bank. Account holder, account ending, savings, and frozen-card state persist per scene. Payment and deposit actions use the captured scene identifier, so their events and balances cannot accidentally affect another active scene.

The references are developer-selected promotional screens. They often contain overlays, rotated phones, crops, photos, or multiple app surfaces in one image. They do not establish every live screen, exact current typography, all account product combinations, animation behavior, authentication, or a complete screen-by-screen match. Wordmark drawing and missing product artwork are approximations. Core account/activity/payment/card behavior is a local scene simulation.

## Verification boundary

The source must compile against the Apple iOS SDK and run in an iPhone simulator before making a release claim. Screenshot comparisons must use matching device size, displayed state, and bank product. An exact 1:1 claim requires these visual comparisons; merely collecting screenshots is not sufficient.

System-delivered iOS notifications still identify the installed app by its bundle name and icon. In-app content cannot change that operating-system attribution.
