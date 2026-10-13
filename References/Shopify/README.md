# Shopify iPhone reference research

Retrieved 2026-10-13 from first-party sources. These files are reference material; they are not bundled application assets. No app source was changed by this research.

## Sources

- App Store listing: https://apps.apple.com/us/app/shopify-sell-run-a-business/id371294472
- Apple's public listing metadata: https://itunes.apple.com/lookup?id=371294472&country=us
- Shopify mobile product page: https://www.shopify.com/mobile

`itunes-lookup-2026-10-13.json` preserves the lookup response. It reports seller **Shopify Inc.**, version **10.2640.0**, release **2026-10-05T13:13:36Z**, and minimum iOS **16.0**. App Store screenshots were fetched from the exact image URLs in `screenshotUrls`, with Apple's requested output size increased from `320x480bb.jpg` to `1320x2868bb.jpg`. This changes the requested image resolution, not its content.

`mobile-assets.json` maps Shopify product-page reference filenames to their exact CDN URLs. The product page gives no version or screenshot date, so its appearance cannot be asserted to match the current App Store binary.

## Viewed reference images

Images listed below were downloaded and visually inspected with the image viewer. App Store files are 1320 × 2868 promotional posters with a visible app screen inside a phone rendering. Product-page references combine phone screens with marketing overlays.

| File | Evidence visible inside the phone | Marketing elements to exclude from implementation |
| --- | --- | --- |
| `app-store-07-pulse-analytics.jpg` | Current home: black header and chart area; purple user avatar left; store icon and name centered; bell with red badge right; horizontally scrollable metrics; blue actual/dashed gray comparison chart; white rounded lower content area; floating bottom toolbar. | Poster title, outer phone hardware, background, fixed example data. |
| `app-store-05-order-fulfillment.jpg` | Orders list: black Orders heading; plus and more buttons; white rounded sheet; search, location, sort and filter controls; All/Unfulfilled/Unpaid/Open/Archived tabs; date headers; order rows with statuses. | Oversized floating Fulfilled/Paid chips, shipping-label card, dark fade near bottom, poster heading, phone hardware. |
| `mobile-analytics-watch.webp` | Alternate analytics design: black store header with store identity left and bell/avatar right; white rounded analytics sheet; date-range, live visitors and Report row; sessions/sales/orders metrics; blue chart; two gray task cards. | Apple Watch, physical phone frame, scenic backdrop. Version unknown. |
| `mobile-sales.webp` | Order detail rows with product image, product name, variant, price and right-aligned quantity; dark Fulfill items button. Notification wording is visible. | Enlarged notification extends outside the phone; its size is a marketing composition, not reliable iOS pixel geometry. |
| `app-store-04-checkout.jpg` | Customer checkout: white shop-name header, summary strip, express-pay methods and contact/delivery form. | This is storefront customer checkout, not the merchant dashboard; exclude from dashboard fidelity scope. |
| `app-store-02-quick-sale.jpg` | Amount and Tap to Pay/Payment link/Cash sheet. | Photo showing the back of an iPhone, poster heading, promotional scale of sheet. |
| `app-store-06-inventory.jpg` | Scanned-item card with product thumbnail, name, variant, price, quantity stepper, green picked status and dark Review scanned items button. | Photo barcode scene, scan-corner graphics and oversized promotional composition. |

`mobile-hero.webp`, `mobile-store.webp`, and `mobile-orders.webp` are lifestyle photos, not UI references. `mobile-next.webp` and `mobile-last.webp` are Sidekick marketing compositions. They were inspected but do not improve home/orders fidelity.

## Concrete SwiftUI implementation guidance

### Current App Store home

- Use a black root background through the top safe area. Preserve the system status bar instead of drawing a counterfeit one.
- Place a compact horizontal header above the metrics: circular avatar button, centered store avatar/name, bell button and red count badge. Home store title is compact, not a large navigation title.
- Use a horizontally scrolling strip of metrics: Live, Total sales, Orders, Conversion rate. The selected metric has a dark-gray rounded rectangle. In the reference the Total sales value is white bold with a small green percentage increase on the same row.
- Render a blue curved line chart against black, with thin gray horizontal rules, gray value/time labels, and a gray-blue dashed comparison line. The chart has no bright filled area in this reference.
- Put the following sections in a white sheet with approximately 20-point top corner radii: greeting, horizontally scrolling action cards, Pulse insight card. The action cards use white fill, faint gray border, subtle shadow, and compact caption/value/icon layout.
- The reference shows a purple-gradient Pulse card title area, a white body with bold recommendation title, gray body text, and a pill-shaped action button.
- At the bottom use a circular search button, a larger rounded floating capsule containing home/orders/products/menu symbols, and a circular assistant button. Selected home has a light-gray circular background and dark symbol. Other icons are gray. In SwiftUI, reserve bottom content clearance with `safeAreaInset` so the controls do not obscure the last row.

### Orders

- Title and header actions sit on black. The list controls/body are one white sheet with rounded top corners.
- Search uses light-gray fill and a magnifying-glass symbol; location, sort and filter controls are gray circles with dark symbols.
- Status tabs are horizontally scrollable. Selected All has a gray rounded-pill background; the other tabs are plain dark text.
- Date separators have pale-gray background and small medium-gray text.
- Each order row has bold order number on the left and amount on the right; beneath it is `Customer • N items • time`; then status chips and shipping method. Avoid large colored accent cards.
- Unfulfilled status uses a muted yellow pill; Paid uses a neutral gray pill. The floating bright-green Fulfilled chip in the poster is an annotation, not evidence for an oversized row badge.

### Alternate white analytics view

- The first-party product-page reference supports a white analytics sheet under a black store header. Implement it as a separate analytics route or explicit visual preset; do not silently treat it as the newest home layout.
- Top controls: Last 7 days gray pill with downward chevron, green live dot and visitors outlined pill, outlined Report button.
- The active Sessions metric is large/dark; neighboring Total sales and Total orders are compact/muted. Increases use green diagonal arrow symbols.
- Chart line is blue, horizontal rules are very pale gray, axes are gray. The chart is not inside an independent card.
- Two task cards use gray fill, counts in bold, task text below, and small line icons aligned near the upper right.

### Notification text

Shopify's product-page example reads:

> [Purple Vine] You have a new order for 2 items totaling $265.

The system heading reads Shopify. A Reverie local notification can reproduce the body format, but iOS supplies the installed app's own name/icon. The promotional enlarged banner does not prove exact system banner padding, font sizes, or width.

## Fidelity limits

These sources can ground the visible composition of the cited home, analytics, orders, and order-detail portions. They do not expose all app screens, interactive states, dynamic type behavior, error/loading states, motion, notification sound, or exact dimensions. The current App Store poster does not establish that its screenshot was taken from the exact listed app version. No complete 1:1 claim is justified without running the target and comparing screenshots on the same iPhone/iOS configuration.

App Store screenshots include first-party marks and copyrighted product photos. Keep them as research references rather than redistributing them inside the app. Use custom product imagery and the app's own identity for the actual simulation.
