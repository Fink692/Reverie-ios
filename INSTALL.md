# Install Reverie on iPhone

The app requires **iOS 17 or later**. An unsigned IPA must be signed for your device before iOS can run it. These instructions were checked against the official documentation on 13 October 2026; installation on a physical iPhone has not been tested in this workspace.

## Choose a build

Download and extract `Reverie-unsigned-apps` for iPhone IPAs, or `Reverie-ios-build` for simulator and test evidence from a successful run in [GitHub Actions](https://github.com/Fink692/Reverie-ios/actions). Check that the selected run includes successful device, test, and variant-build steps.

| File | Use |
|---|---|
| `Reverie-unsigned.ipa` | Base Reverie app with all scene appearances. |
| `brand-artifacts/Reverie-commerce-unsigned.ipa` | Commerce variant with its own Shopify display name and icon. |
| `brand-artifacts/Reverie-<bank>-unsigned.ipa` | Bank variant, for example `chase`, `monzo`, or `revolut`, with its own display name and icon. |
| `brand-artifacts/Reverie-<brand>-unsigned.ipa` | Investing, wallet, or prediction variant, e.g. `coinbase`, `phantom`, or `polymarket`. |
| `Reverie-simulator.zip` | Mac iOS Simulator build. Use source if its architecture/runtime does not match your Mac. |

The variants use distinct `com.reverie.brand.*` bundle identifiers, listed in [variants.json](References/Branding/variants.json). They remain fictional roleplay apps. They do not replace or connect to the official apps. iOS uses the installed variant's display name and icon for its own local notifications; choosing another bank inside the app does not rename that installed app. A branded variant restores its configured appearance on relaunch while preserving scene data.

## Sideloadly: Windows or Mac

1. Download [Sideloadly from its official website](https://sideloadly.io/). On Windows, follow its current prerequisites for Apple's web versions of iTunes and iCloud.
2. Connect your unlocked iPhone by USB and accept **Trust This Computer**. Select that device in Sideloadly.
3. Drop your chosen `.ipa` into Sideloadly, enter your Apple Account there, and start signing/installing. Enter any password or verification code only in the signing tool's authentication prompt. **Never send credentials in chat or commit them to this repository.**
4. Follow the tool's [trust and Developer Mode instructions](https://sideloadly.io/faq.html). The usual locations are **Settings → General → VPN & Device Management** and **Settings → Privacy & Security → Developer Mode**. Complete the required restart and confirmation.
5. Enable automatic refresh if desired. Its daemon needs the computer running and your phone reachable by USB or configured Wi-Fi sync.

For updates, keep the same Apple Account and resulting bundle identifier. Export your session before reinstalling; [Sideloadly's FAQ](https://sideloadly.io/faq.html) explains updating over an existing installation.

## AltStore Classic: Windows or Mac

1. Follow the official [Windows guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) or [Mac guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos) to install AltServer on your computer, pair the phone, and install **AltStore Classic**. Complete trust and Developer Mode prompts. Authenticate in the tool only.
2. Save your chosen IPA in the iPhone's Files app. In AltStore Classic, open **My Apps**, tap **+**, and select it.
3. Keep AltServer running while importing or refreshing. The phone must share its network or connect by USB. Use **Refresh All** before expiration. See [Getting Started](https://faq.altstore.io/altstore-classic/your-altstore) and [AltServer](https://faq.altstore.io/altstore-classic/altserver).

## Free-account limits

[Apple's Personal Team rules](https://developer.apple.com/help/account/basics/about-your-developer-account) allow up to **3 installed development apps per device**, **10 App IDs**, and **3 registered devices**. App IDs/device registrations and provisioning expire after **7 days**. Refresh or rebuild before the app expires. Each variant has a different App ID. Removing an app does not immediately free an unexpired App ID.

AltStore Classic itself occupies one app slot, normally leaving two for these variants. Sideloadly requires no companion iPhone app. You cannot keep all twenty variants installed simultaneously with a free account. [AltStore's App IDs guide](https://faq.altstore.io/altstore-classic/app-ids) explains the separate ID quota.

## Xcode: install from source on a Mac

Open `Reverie.xcodeproj` in current Xcode. Add your Apple Account in Xcode settings. Select the Reverie target, enable **Automatically manage signing**, choose your team, and set a personal, unique bundle identifier. Connect your phone, select it as the run destination, and press **Run**. Complete Developer Mode prompts. A free Personal Team can run this app's local notifications; a paid membership is not required for this route. Follow [Apple's device-run guide](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html) and [Developer Mode guide](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).

## Simulator on a Mac

Open the source project, choose an iPhone simulator with iOS 17+, and press **Run**; no Apple signing account is needed. Alternatively, extract `Reverie-simulator.zip`, boot a compatible simulator, and run:

```bash
xcrun simctl install booted /path/to/Reverie.app
xcrun simctl launch booted com.reverie.simulator
```

## First launch

Complete the onboarding explaining that figures and notifications are fictional. Edit your scene, totals, account holder, and currency in Studio. Use **Open scene** for playback; variants open their configured scene after onboarding. Enable notification permission when scheduling alerts. Sessions stay local and can be exported from Settings. No real service login, wallet recovery phrase, or private key is needed.

Variants start with **Clean playback** enabled: return to Studio through a profile/menu → **Close scene**, or hold the bank name for **two seconds**. Settings → Clean playback can restore visible close and bank-selection controls.
