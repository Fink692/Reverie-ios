# Shopify notification audio research

Checked 2026-10-13. **No verified official downloadable Shopify iPhone order-notification sound was found in the public first-party sources examined.** This is a research result, not proof that no public file exists anywhere.

## First-party evidence

- [Shopify Help Center: Troubleshooting the Shopify app](https://help.shopify.com/en/manual/shopify-admin/shopify-app/troubleshooting-shopify-app) names the Shopify Cha-Ching sound in Android instructions for installing sounds from within the app. It describes iOS notification sound enablement, but does not publish an audio download or the iPhone sound's filename, duration, waveform, codec, or version.
- [Shopify mobile product page](https://www.shopify.com/mobile) shows merchant notifications and UI. Its public HTML has no order-sound link ending in MP3, WAV, CAF, AIFF, or M4A.
- Apple's [current Shopify App Store listing](https://apps.apple.com/us/app/shopify-sell-run-a-business/id371294472) and [public lookup response](https://itunes.apple.com/lookup?id=371294472&country=us) do not expose a notification audio asset.

The Help Center statement about iOS sound settings concerns the user's device settings. It does not mean an iOS developer cannot bundle a custom notification sound in its own app. It also does not provide another app with access to Shopify's bundled clip.

## Search coverage and provenance limits

Searched official Shopify domains/CDN with combinations of Shopify, Cha-Ching, cash register, notification sound, download, MP3, WAV, and audio assets. Search returned current official support documentation and community discussions, but no first-party audio download.

Shopify Community members point to third-party sound sites, Blogspot pages, and YouTube uploads. A file described by those publishers as Shopify's sound does not establish that Shopify distributed it, that it matches the latest iPhone app, or that redistribution is permitted. Third-party clips were not downloaded.

No private application bundle was extracted, no authenticated Shopify resources were accessed, and no authentication or other access restriction was bypassed. The initial research did not change application sources. A separately created original cue is documented below.

## Implementation consequence

Neither iOS's default notification sound nor Reverie's original cue has been verified to match Shopify's order sound. Exact sound fidelity remains unverified until a legitimate first-party/public asset or a user-authorized reference with appropriate rights is supplied and compared on a device.

## Reverie's original commerce cue

`Sources/Order.caf` is an **original cash-register-inspired approximation**, not an extracted or copied Shopify Cha-Ching recording. Its entire waveform is synthesized from mathematical oscillators and seeded noise: a lever click, brief drawer-ratchet transients, two inharmonic coin contacts, and damped bell resonances. No third-party audio sample or Shopify waveform was used.

- Container: Core Audio Format (CAF).
- Encoding: 16-bit signed linear PCM, little endian.
- Channels and rate: mono, 44,100 Hz.
- Duration: 1.65 seconds.
- Signal validation: peak −2.62 dBFS; RMS −19.89 dBFS; zero clipped samples; final sample is zero.
- CAF SHA-256: `b95a4bc40e5e5d18ac624099f514dad82fda7d942232897def3751a730cfb143`.

`scripts/generate-order-sound.py` is the reproducible source. It uses Python's standard library for synthesis and ffmpeg to package the PCM waveform as CAF. Run `python3 scripts/generate-order-sound.py`; optionally supply `--preview-wav /tmp/reverie-order.wav` for a WAV audition. `ffprobe` confirms the resulting CAF format, rate, channels, PCM encoding, and duration. A second independent generation produced the same CAF SHA-256. A decoded MP3 preview was rendered through the audio-output tool; this environment does not support subjective audio-input inspection. Device playback must still be checked with silent mode, notification sound settings, and Focus settings.

The commerce notification may use `UNNotificationSound(named: UNNotificationSoundName("Order.caf"))` once the file is included in the application resource bundle. The sound is an original sale cue and must not be called an exact Shopify recording.
