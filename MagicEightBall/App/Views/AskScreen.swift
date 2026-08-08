import SwiftUI
import EightBallCore

/// The main screen: type a question, shake or tap, get a reading.
@MainActor
struct AskScreen: View {
    @EnvironmentObject private var store: SubscriptionManager
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var history: HistoryStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var question: String = ""
    @State private var prediction: Prediction?
    @State private var phase: AskPhase = .idle
    @State private var wobble: Double = 0
    @State private var revealTask: Task<Void, Never>?

    /// Bumped for blank questions so each shake genuinely re-draws; a typed
    /// question is instead seeded from its own text.
    @State private var blankVariant: Int = 0

    @State private var paywallFeature: ProFeature?
    @State private var isReplay = false

    @FocusState private var questionFocused: Bool

    private let oracle = Oracle()

    private var isPro: Bool { store.isPro }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        header
                        ball
                        actionArea
                        readingDetail
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Eight Ball Oracle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isPro {
                        Button("Go Pro") { paywallFeature = .unlimitedAsks }
                            .font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier(A11y.goProButton)
                    }
                }
            }
        }
        .onDeviceShake { ask() }
        .onChange(of: scenePhase) { _, newPhase in
            // Coming back from the background after midnight would otherwise
            // leave a stale "0 asks left" on screen.
            if newPhase == .active { preferences.objectWillChange.send() }
        }
        .sheet(item: $paywallFeature) { feature in
            PaywallView(highlight: feature)
                .environmentObject(store)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            TextField("Ask a yes-or-no question…", text: $question, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.title3)
                .lineLimit(1...3)
                .focused($questionFocused)
                .submitLabel(.done)
                .onSubmit { ask() }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .accessibilityLabel("Your question")
                .accessibilityIdentifier(A11y.questionField)

            HStack(spacing: 10) {
                Label(preferences.activeScaleName(isPro: isPro), systemImage: "dial.medium")
                Text("·")
                Text(quotaText)
                    .accessibilityIdentifier(A11y.quotaLabel)
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 8)
    }

    private var quotaText: String {
        guard let remaining = preferences.remainingAsks(isPro: isPro) else { return "Unlimited" }
        return remaining == 1 ? "1 question left today" : "\(remaining) questions left today"
    }

    // MARK: - Ball

    private var ball: some View {
        EightBallView(
            prediction: prediction,
            phase: phase,
            size: 300,
            reduceMotion: reduceMotion,
            wobble: wobble
        )
        .frame(maxWidth: .infinity)
        .contentShape(Circle())
        .onTapGesture { ask() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to ask the ball")
        .accessibilityIdentifier(A11y.ball)
    }

    // MARK: - Actions

    private var actionArea: some View {
        VStack(spacing: 12) {
            Button(action: { ask() }) {
                Label(phase == .thinking ? "Consulting…" : "Ask the Ball", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accent.opacity(phase == .thinking ? 0.4 : 0.95))
            )
            .foregroundStyle(.white)
            .disabled(phase == .thinking)
            .accessibilityIdentifier(A11y.askButton)

            if canOfferReroll {
                Button(action: { askAgain() }) {
                    Label(
                        isPro ? "Ask again" : "Ask again (Pro)",
                        systemImage: isPro ? "arrow.clockwise" : "lock.fill"
                    )
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.09))
                )
                .foregroundStyle(.white.opacity(0.9))
                .accessibilityIdentifier(A11y.askAgainButton)
            }

            if !isPro, preferences.remainingAsks(isPro: false) == 0 {
                Text("The ball rests until midnight. Pro removes the limit.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var canOfferReroll: Bool {
        phase == .revealed && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Reading detail

    @ViewBuilder
    private var readingDetail: some View {
        if phase == .revealed, let prediction {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(prediction.sentiment.displayName, systemImage: prediction.sentiment.symbolName)
                        .font(.headline)
                        .foregroundStyle(Theme.tint(for: prediction.sentiment))
                        .accessibilityIdentifier(A11y.readingVerdict)
                    Spacer()
                    Text("\(prediction.likelihoodPercent)% chance of yes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                LikelihoodBar(likelihood: prediction.likelihood, sentiment: prediction.sentiment)

                HStack {
                    Text(prediction.packName)
                    Spacer()
                    if isReplay {
                        Text("Today's answer — the ball doesn't change its mind.")
                            .multilineTextAlignment(.trailing)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
            }
            .cardStyle()
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier(A11y.readingCard)
        }
    }

    // MARK: - Ask flow

    private func ask() {
        guard phase != .thinking else { return }
        questionFocused = false

        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)

        // A question already answered today replays for free rather than
        // re-rolling, so the answer is stable and the quota isn't burned.
        if !trimmed.isEmpty, let existing = history.todaysEntry(for: trimmed) {
            beginSequence(with: existing.prediction, replay: true)
            return
        }

        guard preferences.canAsk(isPro: isPro) else {
            Feedback.blocked(enabled: preferences.hapticsEnabled)
            paywallFeature = .unlimitedAsks
            return
        }

        preferences.consumeAsk(isPro: isPro)
        draw(question: trimmed, variant: trimmed.isEmpty ? nextBlankVariant() : 0)
    }

    private func askAgain() {
        guard isPro else {
            Feedback.blocked(enabled: preferences.hapticsEnabled)
            paywallFeature = .askAgain
            return
        }
        guard phase != .thinking else { return }

        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextVariant = (history.latestVariant(for: trimmed) ?? 0) + 1

        preferences.consumeAsk(isPro: true)
        draw(question: trimmed, variant: nextVariant)
    }

    private func nextBlankVariant() -> Int {
        blankVariant &+= 1
        return blankVariant
    }

    private func draw(question trimmed: String, variant: Int) {
        let reading = oracle.predict(
            question: trimmed,
            scale: preferences.activeScale(isPro: isPro),
            allowedPackIDs: preferences.activePackIDs(isPro: isPro),
            date: Date(),
            variant: variant
        )
        history.add(reading)
        beginSequence(with: reading, replay: false)
    }

    /// Shake, pause, reveal.
    private func beginSequence(with reading: Prediction, replay: Bool) {
        revealTask?.cancel()
        isReplay = replay

        Feedback.shakeStarted(enabled: preferences.hapticsEnabled)

        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .thinking
        }

        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.11).repeatCount(9, autoreverses: true)) {
                wobble = 7
            }
        }

        let delay: Duration = reduceMotion ? .milliseconds(350) : .milliseconds(1_250)

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }

            wobble = 0
            prediction = reading
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                phase = .revealed
            }
            Feedback.revealed(
                reading.sentiment,
                haptics: preferences.hapticsEnabled,
                sound: preferences.soundEnabled
            )
        }
    }
}
