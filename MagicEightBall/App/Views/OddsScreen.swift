import SwiftUI
import EightBallCore

/// Where the probability scale is chosen or tuned.
@MainActor
struct OddsScreen: View {
    @EnvironmentObject private var store: SubscriptionManager
    @EnvironmentObject private var preferences: Preferences

    @State private var paywallFeature: ProFeature?

    private var isPro: Bool { store.isPro }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        currentScaleCard
                        presetSection
                        customSection
                        packSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Odds")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $paywallFeature) { feature in
                PaywallView(highlight: feature)
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Current

    private var currentScaleCard: some View {
        let scale = preferences.activeScale(isPro: isPro)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("In use")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(preferences.activeScaleName(isPro: isPro))
                    .font(.subheadline.weight(.semibold))
            }
            ScaleWeightBar(scale: scale)
            Text("Out of every 100 questions, the ball says yes about \(scale.displayPercentages.affirmative) times.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    // MARK: - Presets

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.headline)

            ForEach(ScalePreset.all) { preset in
                presetRow(preset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func presetRow(_ preset: ScalePreset) -> some View {
        let locked = preset.requiresPro && !isPro
        let isSelected = !preferences.usingCustomScale && preferences.presetID == preset.id && !locked

        return Button {
            guard !locked else {
                paywallFeature = .customProbability
                return
            }
            Feedback.selection(enabled: preferences.hapticsEnabled)
            preferences.usingCustomScale = false
            preferences.presetID = preset.id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: locked ? "lock.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .foregroundStyle(locked ? .white.opacity(0.4) : (isSelected ? Theme.accent : .white.opacity(0.4)))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.name).font(.subheadline.weight(.semibold))
                    Text(preset.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    ScaleWeightBar(scale: preset.scale, height: 8, showsLabels: false)
                        .opacity(locked ? 0.45 : 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    // MARK: - Custom

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Custom scale").font(.headline)
                Spacer()
                if isPro {
                    Toggle("", isOn: Binding(
                        get: { preferences.usingCustomScale },
                        set: { preferences.usingCustomScale = $0 }
                    ))
                    .labelsHidden()
                } else {
                    Label("Pro", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            if isPro {
                ScaleWeightBar(scale: preferences.customScale)

                weightSlider(
                    title: "Yes",
                    sentiment: .affirmative,
                    value: Binding(
                        get: { preferences.customScale.affirmative * 100 },
                        set: { updateCustom(affirmative: $0) }
                    )
                )
                weightSlider(
                    title: "Maybe",
                    sentiment: .noncommittal,
                    value: Binding(
                        get: { preferences.customScale.noncommittal * 100 },
                        set: { updateCustom(noncommittal: $0) }
                    )
                )
                weightSlider(
                    title: "No",
                    sentiment: .negative,
                    value: Binding(
                        get: { preferences.customScale.negative * 100 },
                        set: { updateCustom(negative: $0) }
                    )
                )

                Text("Weights are relative — they're rebalanced to 100% as you drag.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Button {
                    paywallFeature = .customProbability
                } label: {
                    Label("Set your own odds with Pro", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.accent.opacity(0.9))
                )
                .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func weightSlider(title: String, sentiment: Sentiment, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(Theme.tint(for: sentiment))
                .accessibilityLabel("\(title) weight")
        }
    }

    /// Slider edits move one weight and leave the other two untouched; the
    /// scale renormalises, so the displayed percentages settle on their own.
    private func updateCustom(affirmative: Double? = nil, noncommittal: Double? = nil, negative: Double? = nil) {
        let current = preferences.customScale
        preferences.customScale = ProbabilityScale(
            affirmative: affirmative ?? current.affirmative * 100,
            noncommittal: noncommittal ?? current.noncommittal * 100,
            negative: negative ?? current.negative * 100
        )
        preferences.usingCustomScale = true
    }

    // MARK: - Packs

    private var packSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Answer packs")
                .font(.headline)
            Text("Packs change how the ball talks, never how it decides.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

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
