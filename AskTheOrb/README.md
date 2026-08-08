# Ask the Orb

A fortune-telling orb for iOS that shows you the odds behind every
answer — and lets you change them.

Ask a yes-or-no question, shake or tap, and the orb answers. Every reading
also reports the probability that produced it, so you always know whether the
orb was leaning your way. Free tier is a complete app; Pro unlocks unlimited
questions, more answer packs, and control over the odds.

<img src="App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="140" alt="App icon">

---

## How the probability scale works

This is the part worth understanding, because it's the product.

A `ProbabilityScale` is three normalised weights — the chance of a yes, a
maybe, and a no. Drawing a reading happens in two steps that are deliberately
kept apart:

1. **The odds decide the verdict.** A uniform draw is split across the three
   weights, then rescaled into that verdict's fixed third of the 0–1 axis. So
   `P(affirmative)` equals `scale.affirmative` exactly, and the percentage
   shown to the user can never contradict the verdict beside it — a *No* always
   reads under 33%, a *Yes* always over 67%.
2. **The pack decides the wording.** The phrase is picked uniformly from the
   answers of that verdict across the packs the user has unlocked.

Because step 2 can't influence step 1, **buying an answer pack changes the
voice of the orb but never its luck.** There's a test that asserts exactly
that, and another that draws 200,000 times per scale and checks the observed
frequencies land within 1% of what was configured.

Seeding is deterministic: the same question, on the same day, under the same
scale, produces the same answer. The orb doesn't change its mind, and
re-asking a question you already asked today costs nothing against the free
allowance. "Ask again" (Pro) bumps a variant counter to force a genuinely new
draw.

## Free vs Pro

| | Free | Pro |
|---|---|---|
| Questions per day | 5 | Unlimited |
| Answer packs | Classic (20 answers) | All six |
| Probability scale | Classic (10/5/5) | 6 presets + fully custom |
| Ask again / re-roll | — | ✅ |
| History | Last 3 readings | Everything, searchable, with notes |
| Insights | — | ✅ |

Pro is sold as a monthly subscription, a yearly subscription with a 7-day free
trial, or a one-time lifetime unlock. Entitlement is read from
`Transaction.currentEntitlements` on every refresh and never cached to disk, so
a lapsed subscription actually loses Pro and a reinstall restores it without a
Restore tap.

## Layout

```
AskTheOrb/
├── Core/                    Swift package — all logic, no UI, testable anywhere
│   ├── Sources/OrbCore/
│   │   ├── ProbabilityScale.swift   weights, presets, display rounding
│   │   ├── Oracle.swift             the draw, seeding, pack selection
│   │   ├── AnswerPack.swift         six packs, 20 + 5×18 answers
│   │   ├── Entitlements.swift       Pro feature list, free-tier quota
│   │   ├── Prediction.swift         a reading, as persisted
│   │   ├── Sentiment.swift          yes / maybe / no and their bands
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

The core suite covers the odds themselves (frequency checks against each
scale), verdict/percentage coherence, determinism and re-ask behaviour, quota
rollover including backwards clock changes and mid-day subscription lapses, and
catalog integrity.

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

A toy. Answers are drawn at random from the odds you choose. It cannot predict
anything, and the app says so plainly in Settings and in its store listing.
