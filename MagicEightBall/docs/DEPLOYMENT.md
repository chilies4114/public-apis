# Deploying Eight Ball Oracle to the App Store

Everything in this repository is build-ready. What it cannot contain is your
Apple Developer account: signing certificates, a Team ID, an App Store Connect
API key and the registered bundle ID all have to be created under your account
before the first upload. This document is the complete list of what to do, in
order.

**You need a Mac with Xcode 15 or later.** iOS apps cannot be compiled,
signed, or uploaded from Linux — `xcodebuild`, the code-signing toolchain and
the App Store upload transport are all macOS-only.

---

## 0. Prerequisites

| Thing | Where | Cost |
|---|---|---|
| Apple Developer Program membership | [developer.apple.com/programs](https://developer.apple.com/programs/) | $99/year |
| Mac with Xcode 15+ | Mac App Store | — |
| Homebrew | [brew.sh](https://brew.sh) | — |

```bash
brew install xcodegen
sudo gem install bundler   # or use the system Ruby's bundler
cd MagicEightBall
bundle install
```

---

## 1. Choose your identifiers

Three strings have to agree in three places. Pick them once and change them
everywhere before you build.

| Value | Default in this repo | Where it appears |
|---|---|---|
| Bundle ID | `com.eightballoracle.app` | `project.yml`, `fastlane/Appfile`, App Store Connect |
| Monthly product | `com.eightballoracle.pro.monthly` | `App/Store/StoreConfig.swift`, `Configuration/Products.storekit`, App Store Connect |
| Yearly product | `com.eightballoracle.pro.annual` | same three |
| Lifetime product | `com.eightballoracle.pro.lifetime` | same three |

Use a domain you control, in reverse — `com.yourcompany.eightball`. Bundle IDs
are permanent once registered.

```bash
# From MagicEightBall/, replace the placeholder prefix everywhere at once:
grep -rl 'com.eightballoracle' . --exclude-dir=.git \
  | xargs sed -i '' 's/com\.eightballoracle/com.yourcompany.eightball/g'
```

Also replace the two URLs in `App/Store/StoreConfig.swift` (`privacyURL`,
`supportURL`) with pages you actually host. Apple checks that the privacy
policy URL loads; a dead link is a rejection.

---

## 2. Generate and open the project

The `.xcodeproj` is generated, not committed — that keeps it from drifting
from the sources and from producing merge conflicts.

```bash
cd MagicEightBall
xcodegen generate
open EightBallOracle.xcodeproj
```

Signing lives in `Configuration/Signing.xcconfig`. Put your Team ID — the
10-character string at
[developer.apple.com/account](https://developer.apple.com/account) →
Membership — into it once:

```
DEVELOPMENT_TEAM = ABCDE12345
```

Because it's an xcconfig rather than a value baked into the project, it
survives every `xcodegen generate`. Simulator builds work with it left empty.

Build and run on a simulator (⌘R). The scheme already attaches
`Configuration/Products.storekit`, so the paywall shows real-looking prices and
purchases complete locally — no sandbox account, no App Store Connect setup
needed to try the whole flow.

---

## 3. Run the tests

```bash
cd Core && swift test          # probability, quota and catalog logic
cd .. && bundle exec fastlane tests   # UI flows on a simulator
```

The core tests include a 200,000-draw check that the observed yes/maybe/no
frequencies match each configured scale to within 1%. If you change the odds
logic, that test is the one that matters.

---

## 4. Register the app in App Store Connect

1. [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers)
   → **+** → App IDs → App. Enter your bundle ID. Enable **In-App Purchase**
   (it is on by default).
2. [appstoreconnect.apple.com/apps](https://appstoreconnect.apple.com/apps)
   → **+** → New App.
   - Platform: iOS
   - Name: `Eight Ball Oracle` (must be globally unique — have a backup ready)
   - Primary language: English (U.S.)
   - Bundle ID: the one you just registered
   - SKU: anything internal, e.g. `EIGHTBALL001`

---

## 5. Create the three in-app purchases

In App Store Connect → your app → **Monetization**.

**Subscriptions** → create a subscription group named `Eight Ball Pro`, then
add two subscriptions inside it:

| Reference name | Product ID | Duration | Price |
|---|---|---|---|
| Pro Monthly | `com.eightballoracle.pro.monthly` | 1 month | $2.99 |
| Pro Yearly | `com.eightballoracle.pro.annual` | 1 year | $14.99 |

On the yearly subscription add an **Introductory Offer**: Free trial, 1 week,
all territories. That is what makes the paywall's "Start Free Trial" button
appear — the app reads eligibility from StoreKit, so if you skip this the
button correctly falls back to "Continue".

**In-App Purchases** → add one non-consumable:

| Reference name | Product ID | Price |
|---|---|---|
| Pro Lifetime | `com.eightballoracle.pro.lifetime` | $29.99 |

For each of the three: add a display name, a description, and a **review
screenshot** (any screenshot of the paywall is fine). Products stay in "Missing
Metadata" until all three are filled in, and a product that isn't at least
"Ready to Submit" will not load in the app.

> Products can take up to a few hours to become available to the sandbox after
> creation. If the paywall shows "Couldn't reach the App Store" right after
> setup, that's usually why.

---

## 6. Create an App Store Connect API key

This is what lets fastlane (and CI) upload without an Apple ID password or 2FA
prompt.

1. [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api)
   → **+** → Access: **App Manager**.
2. Download the `.p8`. **It can only be downloaded once.**
3. Note the Key ID and the Issuer ID from the same page.

```bash
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_CONTENT=$(base64 -i AuthKey_XXXXXXXXXX.p8)
export DEVELOPMENT_TEAM=YOURTEAMID
export APPLE_ID=you@example.com
```

Keep the `.p8` out of git. `.gitignore` already excludes `*.p8`.

### A note on signing

The lanes use **automatic signing** by default, which is the right choice for a
solo developer — Xcode creates and refreshes the profiles for you and there is
nothing else to set up. If several people or machines need to sign the same
app, set `MATCH_GIT_URL` to a private repository and the lanes will switch to
[fastlane match](https://docs.fastlane.tools/actions/match/) instead. Leaving
it unset skips match entirely rather than failing on an unconfigured repo.

---

## 7. Upload to TestFlight

```bash
bundle exec fastlane beta
```

This regenerates the project, bumps the build number past whatever is already
on TestFlight, signs, archives, and uploads. Processing on Apple's side takes
5–30 minutes; you'll get an email when the build is testable.

Install it on a real device and check, at minimum:

- [ ] Shake gesture triggers a reading (simulator: Device → Shake)
- [ ] Haptics fire on reveal
- [ ] Free tier stops at 5 questions and shows the paywall
- [ ] A sandbox purchase unlocks Pro immediately
- [ ] Deleting and reinstalling restores Pro without tapping Restore
- [ ] Cancelling the sandbox subscription removes Pro on next launch

The last two are the ones App Review actually tests.

---

## 8. Submit for review

Upload the metadata and the build together:

```bash
bundle exec fastlane release
```

Before that runs cleanly you still need, in App Store Connect:

- **Screenshots.** Required: 6.7" (1290×2796) and 6.5" (1242×2688). Generate
  them with `bundle exec fastlane screenshots`, or take them by hand in the
  simulator with ⌘S.
- **Age rating.** Answer the questionnaire. Eight Ball Oracle rates 4+ —
  answer "None" to every content question. Do **not** mark it as gambling; it
  has no wagering and no simulated gambling.
- **App Privacy.** Select "Data Not Collected". This matches
  `App/Resources/PrivacyInfo.xcprivacy`, which declares no collected data
  types.
- **Export compliance.** Already answered by `ITSAppUsesNonExemptEncryption`
  = `false` in `Info.plist`, so you won't be asked each upload.

`fastlane/metadata/review_information/notes.txt` is uploaded automatically and
tells the reviewer how to reach the paywall — that alone prevents a common
"we could not locate the subscription" rejection.

---

## 9. The rejection reasons that actually apply here

These are the guidelines this app touches. The code already satisfies them;
this is what to check if you change things.

**3.1.2 — Subscriptions.** The paywall must show, on the same screen as the
buy button: title, length of subscription, price per period, and links to
Terms of Use and Privacy Policy. `PaywallView` does all four. If you restyle
it, don't drop the `renewalDisclosure` text or the two `Link`s.

**3.1.1 — In-app purchase.** Don't add any other way to pay. No "buy on our
website" link, no crypto, nothing.

**2.1 — App completeness.** Every product must be at least "Ready to Submit"
in App Store Connect, or the paywall renders empty for the reviewer and gets
rejected as a broken feature.

**5.1.1 — Data collection.** The privacy manifest declares nothing collected.
If you add analytics later, both the manifest and the App Privacy answers must
be updated or the build is rejected at upload.

**4.2 — Minimum functionality.** Fortune-teller apps get scrutiny here. The
free tier is deliberately a complete, usable app rather than a demo, and the
Settings/description disclaimers state plainly that it's entertainment.

---

## 10. CI

`.github/workflows/ios.yml` runs the Core package's tests on every push (fast,
Linux) and the full simulator test suite on macOS runners for pull requests. It
does not upload — wiring TestFlight into CI means putting `ASC_KEY_CONTENT`
into repository secrets, which is worth doing only once you're shipping
regularly.

---

## What is not automated

- Creating the Apple Developer account and paying the fee
- Registering the bundle ID and creating the app record
- Creating the three IAP products and their review screenshots
- Answering the age-rating and App Privacy questionnaires
- Hosting the privacy policy and support pages
- The review itself (typically 24–48 hours)

Everything else is `bundle exec fastlane release`.
