# Ask the Orb

A fortune-telling orb for iOS that shows you the exact odds behind every
answer — and lets nobody change them, including us.

Ask a yes-or-no question, shake or tap, and the orb answers. Every reading
states the real chance it was drawn on — "10 in 20" — counted from the pool
rather than estimated. Free tier is a complete app; Pro unlocks unlimited
questions, more answer packs, and a measurement of your own results against
those odds.

<img src="App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="140" alt="App icon">

---

## How the odds work

This is the part worth understanding, because it's the product.

The orb draws **one answer uniformly at random** from every answer the user has
unlocked. That's the whole mechanism. So the chance of a yes isn't a weight
anyone configured — it's a count:

```
Classic pack: 10 yes + 5 maybe + 5 no  =  20 answers
chance of yes = 10 in 20 = 50%
```

There is no separate weighting step, which means there is nothing that could
disagree with the number printed on screen. The ratio *is* the mechanism.

**Every pack ships with the identical 10 / 5 / 5 shape.** Turning packs on grows
the pool but leaves the ratio at exactly 2 : 1 : 1, so buying a pack changes the
orb's vocabulary and provably not its luck. A test walks all 2⁶−1 subsets of
packs and asserts the measured odds never move; another draws 200,000 times and
checks the observed rate lands within 1% of the count.

There is deliberately **no way to change the odds** — not for the player, not
behind a paywall. An oracle you can dial to 90% yes is telling you what you
already decided, and selling that dial would have made the paid tier a way to
rig your own luck.

What Pro does show is the honest counterpart: **your observed results against
the designed odds**, with the sample size and the wobble you should expect at
that size. Over twenty readings a 50% process routinely lands anywhere near
±11 points, and the app says so rather than letting a short run look like a
trend.

Seeding is deterministic: the same question, on the same day, produces the same
answer. The orb doesn't change its mind, and re-asking a question you already
asked today costs nothing against the free allowance. "Ask again" (Pro) bumps a
variant counter to force a genuinely new draw.

## Questions the orb won't answer

Before any draw, the question is screened on device against a list of sensitive
topics. Self-harm, violence, abuse and medical questions are declined outright:
no reading, no ask consumed, nothing written to history, and real support
resources shown instead. Legal and money questions still answer but carry a
standing "not advice" banner.

The screener is a plain phrase list matched on whole-word boundaries — no
network, no model, and no question ever leaves the phone. False positives got as
much attention as catches, because a screener that fires on "should I kill this
feature" gets ignored, and an ignored screener is useless when it matters.

## Free vs Pro

| | Free | Pro |
|---|---|---|
| Questions per day | 5 | Unlimited |
| Answer packs | Classic (20 answers) | All six |
| Odds | 10 in 20 | 10 in 20 — identical, by design |
| Ask again / re-roll | — | ✅ |
| History | Last 3 readings | Everything, searchable, with notes |
| Your results vs the odds | — | ✅ |

Pro is sold as a monthly subscription, a yearly subscription with a 7-day free
trial, or a one-time lifetime unlock. To use the paid tier yourself without
paying: TestFlight purchases are free (they run in the sandbox), offer codes
give permanent free access on a live build, and Debug builds gain a passphrase
unlock in Settings — deliberately compiled out of Release, because a hidden
unlock in a shipping binary is an App Review 2.3.1 rejection. See
[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md#7b-getting-pro-for-free-on-your-own-device). Entitlement is read from
`Transaction.currentEntitlements` on every refresh and never cached to disk, so
a lapsed subscription actually loses Pro and a reinstall restores it without a
Restore tap.

## Layout

```
AskTheOrb/
├── Core/                    Swift package — all logic, no UI, testable anywhere
│   ├── Sources/OrbCore/
│   │   ├── OddsMeasurement.swift   counts the pool; observed-vs-designed
│   │   ├── Oracle.swift             the uniform draw, seeding, pack selection
│   │   ├── AnswerPack.swift         six packs, 20 answers each, all 10/5/5
│   │   ├── SensitiveTopics.swift    screening and support resources
│   │   ├── Disclaimer.swift         one source of truth for the legal text
│   │   ├── Entitlements.swift       Pro feature list, free-tier quota
│   │   ├── Prediction.swift         a reading, as persisted
│   │   ├── Sentiment.swift          yes / maybe / no
│   │   └── SeededGenerator.swift    SplitMix64, for determinism and tests
│   └── Tests/OrbCoreTests/
├── App/                     SwiftUI app target
│   ├── Views/               AskScreen, OddsScreen, HistoryScreen, Settings, Paywall
│   ├── Store/               StoreKit 2, preferences, history persistence
│   ├── Services/            haptics, shake detection
│   └── Resources/           Info.plist, privacy manifest, asset catalog
├── UITests/                 XCUITest flows, incl. the free-tier wall
├── Configuration/           Products.storekit for local purchase testing
├── fastlane/                lanes + App Store metadata
├── docs/DEPLOYMENT.md       full App Store submission walkthrough
└── project.yml              XcodeGen spec (the .xcodeproj is generated)
```

## Building

Requires a Mac with Xcode 15+. iOS apps can't be compiled or signed on Linux.

```bash
brew install xcodegen
cd AskTheOrb
xcodegen generate
open AskTheOrb.xcodeproj
```

⌘R runs it. The scheme attaches `Configuration/Products.storekit`, so the
paywall shows prices and purchases complete locally — no App Store Connect
setup needed to exercise the whole subscription flow.

## Testing

```bash
cd Core && swift test              # logic only; runs on Linux too
bundle exec fastlane tests         # UI flows on a simulator
```

The core suite covers the odds themselves (every pack subset measures the same
ratio; 200,000 draws match it), determinism and re-ask behaviour, the topic
screener in both directions, quota rollover including backwards clock changes
and mid-day subscription lapses, and catalog integrity.

## Shipping

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for the full walkthrough:
identifiers, App Store Connect setup, the three IAP products, API keys,
TestFlight, and the specific App Review guidelines this app touches.

```bash
bundle exec fastlane beta      # → TestFlight
bundle exec fastlane release   # → metadata + build + submit for review
```

## Regenerating the app icon

```bash
python3 scripts/generate_app_icon.py
```

Renders the 1024×1024 icon as flat RGB with no alpha channel, which App Store
Connect requires.

## A note on what this is

A toy. Answers are drawn at random from a fixed pool. It cannot predict
anything, and the app says so on a disclaimer you must acknowledge before you
can use it.
