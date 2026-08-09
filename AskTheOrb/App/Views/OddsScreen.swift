import SwiftUI
import OrbCore

/// Where the odds are *shown*, not set.
///
/// There used to be presets and sliders here. They're gone: letting someone
/// dial their own fortune to 90% yes makes the number meaningless, and it made
/// the paid tier a way to rig your own luck. What's left is a measurement —
/// what the odds actually are, and what results the user actually got.
@MainActor
struct OddsScreen: View {
    @EnvironmentObject private var store: SubscriptionManager
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var history: HistoryStore

    @State private var paywallFeature: ProFeature?

    private var isPro: Bool { store.isPro }
    private var odds: OddsMeasurement { preferences.measuredOdds(isPro: isPro) }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        measurementCard
                        howItWorksCard
                        observedCard
                        packSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Odds")
            .sheet(item: $paywallFeature) { feature in
                PaywallView(highlight: feature).environmentObject(store)
            }
        }
    }

    // MARK: - The measurement

    private var measurementCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Chance of yes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .textCase(.uppercase)
                .kerning(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(odds.chanceDescription(of: .affirmative))
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                Text("\(odds.percentages.affirmative)%")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.tint(for: .affirmative))
            }

            OddsBar(odds: odds)

            Text("Yes : Maybe : No is \(odds.ratioDescription), counted from the \(odds.total) answers the orb is drawing from right now.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why you can't change it")
                .font(.headline)

            Text("""
                The orb picks one answer at random from the pool, so the chance of a yes is simply how many answers say yes. There's no separate dial, which means there's nothing to turn — not by you, and not by us.

                Every pack ships with the same shape: 10 yes, 5 maybe, 5 no. Turning packs on changes what the orb says. It cannot change what it decides.
                """)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Observed

    @ViewBuilder
    private var observedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your results").font(.headline)
                Spacer()
                if !isPro {
                    Label("Pro", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            if isPro {
                ObservedComparison(expected: odds, observed: history.observedOdds)
            } else {
                Text("Pro tracks every reading and shows how your actual results compare with the odds above.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    paywallFeature = .insights
                } label: {
                    Label("See your results with Pro", systemImage: "chart.bar.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent.opacity(0.9)))
                .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Packs

    private var packSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Answer packs")
                .font(.headline)
            Text("Each pack is 20 answers in the same 10 / 5 / 5 shape, so switching them changes the orb's vocabulary and nothing else.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(AnswerCatalog.all) { pack in
                packRow(pack)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func packRow(_ pack: AnswerPack) -> some View {
        let locked = pack.requiresPro && !isPro
        let enabled = preferences.activePackIDs(isPro: isPro).contains(pack.id)

        return Button {
            guard !locked else {
                paywallFeature = .allAnswerPacks
                return
            }
            togglePack(pack)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: pack.symbolName)
                    .frame(width: 26)
                    .foregroundStyle(Theme.accent.opacity(locked ? 0.4 : 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name).font(.subheadline.weight(.semibold))
                    Text(pack.tagline)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: locked ? "lock.fill" : (enabled ? "checkmark.circle.fill" : "circle"))
                    .foregroundStyle(locked ? .white.opacity(0.4) : (enabled ? Theme.accent : .white.opacity(0.35)))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private func togglePack(_ pack: AnswerPack) {
        var ids = preferences.enabledPackIDs
        if ids.contains(pack.id) {
            ids.remove(pack.id)
            // Turning off the last pack would leave nothing to say, so keep one.
            if ids.isEmpty { ids = [AnswerCatalog.classicPackID] }
        } else {
            ids.insert(pack.id)
        }
        Feedback.selection(enabled: preferences.hapticsEnabled)
        preferences.enabledPackIDs = ids
    }
}
