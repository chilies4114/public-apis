import SwiftUI
import EightBallCore

@MainActor
struct HistoryScreen: View {
    @EnvironmentObject private var store: SubscriptionManager
    @EnvironmentObject private var history: HistoryStore

    @State private var paywallFeature: ProFeature?
    @State private var editingEntry: HistoryStore.Entry?
    @State private var showClearConfirmation = false

    private var isPro: Bool { store.isPro }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                if history.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            if isPro { insightsCard }
                            ForEach(history.visibleEntries) { entry in
                                entryCard(entry)
                            }
                            if history.lockedEntryCount > 0 { lockedFooter }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("History")
            .searchable(text: $history.searchText, prompt: "Search questions and notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !history.entries.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete all readings?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) { history.deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every reading stored on this device. It can't be undone.")
            }
            .sheet(item: $paywallFeature) { feature in
                PaywallView(highlight: feature).environmentObject(store)
            }
            .sheet(item: $editingEntry) { entry in
                NoteEditor(entry: entry) { note in
                    history.updateNote(note, for: entry.id)
                }
            }
        }
    }

    // MARK: - Pieces

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.35))
            Text("No readings yet")
                .font(.headline)
            Text("Ask the ball something and it'll show up here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var insightsCard: some View {
        let insights = history.insights

        return VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)

            HStack(spacing: 18) {
                statistic("Readings", "\(insights.total)")
                statistic("Avg. chance", "\(Int((insights.averageLikelihood * 100).rounded()))%")
                statistic("Yes rate", "\(Int((insights.share(of: .affirmative) * 100).rounded()))%")
            }

            ForEach(Sentiment.allCases.reversed(), id: \.self) { sentiment in
                HStack(spacing: 10) {
                    Circle().fill(Theme.tint(for: sentiment)).frame(width: 8, height: 8)
                    Text(sentiment.displayName)
                        .font(.caption)
                        .frame(width: 46, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Theme.tint(for: sentiment).opacity(0.8))
                            .frame(width: max(2, proxy.size.width * insights.share(of: sentiment)))
                    }
                    .frame(height: 8)
                    Text("\(insights.counts[sentiment, default: 0])")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func statistic(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.bold).monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func entryCard(_ entry: HistoryStore.Entry) -> some View {
        let prediction = entry.prediction

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(prediction.question.isEmpty ? "Unspoken question" : prediction.question)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(prediction.question.isEmpty ? .white.opacity(0.5) : .white)
                Spacer()
                Text(prediction.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Text(prediction.answerText)
                .font(.body)
                .foregroundStyle(Theme.tint(for: prediction.sentiment))
                .fixedSize(horizontal: false, vertical: true)

            LikelihoodBar(likelihood: prediction.likelihood, sentiment: prediction.sentiment, height: 8)

            HStack {
                Text("\(prediction.likelihoodPercent)% chance of yes · \(prediction.packName)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if prediction.variant > 0 {
                    Text("re-ask #\(prediction.variant)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
            }

            HStack(spacing: 16) {
                Button {
                    guard isPro else { paywallFeature = .fullHistory; return }
                    editingEntry = entry
                } label: {
                    Label(entry.note.isEmpty ? "Add note" : "Edit note", systemImage: "square.and.pencil")
                        .font(.caption)
                }
                Spacer()
                Button(role: .destructive) {
                    history.delete(entry.id)
                } label: {
                    Label("Delete", systemImage: "trash").font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.6))
        }
        .cardStyle()
    }

    private var lockedFooter: some View {
        Button {
            paywallFeature = .fullHistory
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                Text("\(history.lockedEntryCount) older reading\(history.lockedEntryCount == 1 ? "" : "s") are saved but hidden")
                    .font(.subheadline.weight(.semibold))
                Text("Pro keeps your whole archive, searchable, with notes.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .cardStyle(padding: 20)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

/// Simple sheet for the Pro note field.
private struct NoteEditor: View {
    let entry: HistoryStore.Entry
    let onSave: (String) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(entry: HistoryStore.Entry, onSave: @escaping (String) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _text = State(initialValue: entry.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your note") {
                    TextField("What happened?", text: $text, axis: .vertical)
                        .lineLimit(3...10)
                }
                Section("Reading") {
                    Text(entry.prediction.answerText)
                    Text("\(entry.prediction.likelihoodPercent)% chance of yes")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
