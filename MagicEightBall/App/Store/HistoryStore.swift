import Foundation
import Combine
import EightBallCore

/// Persisted list of past readings.
///
/// Free users keep the last `FreeTier.historyLimit` readings; Pro keeps
/// everything. Older entries are *retained on disk* when Pro lapses rather than
/// deleted, so resubscribing restores the archive instead of losing it — but
/// they are not readable while unentitled.
///
/// Main-thread only, like `Preferences`.
final class HistoryStore: ObservableObject {

    /// A reading plus anything the user added to it afterwards.
    struct Entry: Identifiable, Codable, Hashable {
        let prediction: Prediction
        var note: String

        var id: UUID { prediction.id }

        init(prediction: Prediction, note: String = "") {
            self.prediction = prediction
            self.note = note
        }
    }

    /// Hard ceiling so the file can't grow without bound on a long-lived install.
    static let maximumStoredEntries = 1_000

    @Published private(set) var entries: [Entry] = []
    @Published var searchText: String = ""

    private let fileURL: URL
    private var isPro: Bool = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    // MARK: - Reading

    /// What the current tier is allowed to see.
    var visibleEntries: [Entry] {
        let allowed = isPro ? entries : Array(entries.prefix(FreeTier.historyLimit))
        guard !searchText.isEmpty else { return allowed }

        let needle = searchText.lowercased()
        return allowed.filter {
            $0.prediction.question.lowercased().contains(needle)
                || $0.prediction.answerText.lowercased().contains(needle)
                || $0.note.lowercased().contains(needle)
        }
    }

    /// How many readings exist beyond what the free tier can see.
    var lockedEntryCount: Int {
        isPro ? 0 : max(0, entries.count - FreeTier.historyLimit)
    }

    /// Whether this question already has a reading today — drives "ask again".
    func hasReading(for question: String, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        latestVariant(for: question, on: date, calendar: calendar) != nil
    }

    /// Highest variant already used for this question today, or nil if unasked.
    func latestVariant(for question: String, on date: Date = Date(), calendar: Calendar = .current) -> Int? {
        todaysEntry(for: question, on: date, calendar: calendar)?.prediction.variant
    }

    /// The most recent reading for this question today, if there is one.
    ///
    /// Re-asking the same question the same day replays this instead of drawing
    /// again — it costs no quota, and it's what makes the ball feel decided
    /// rather than slot-machine-like.
    func todaysEntry(for question: String, on date: Date = Date(), calendar: Calendar = .current) -> Entry? {
        let key = Oracle.normalize(question)
        guard !key.isEmpty else { return nil }
        let day = calendar.startOfDay(for: date)

        return entries
            .filter {
                Oracle.normalize($0.prediction.question) == key
                    && calendar.startOfDay(for: $0.prediction.date) == day
            }
            .max { $0.prediction.variant < $1.prediction.variant }
    }

    // MARK: - Writing

    func add(_ prediction: Prediction) {
        entries.insert(Entry(prediction: prediction), at: 0)
        if entries.count > Self.maximumStoredEntries {
            entries.removeLast(entries.count - Self.maximumStoredEntries)
        }
        save()
    }

    func updateNote(_ note: String, for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].note = note
        save()
    }

    func delete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func deleteAll() {
        entries.removeAll()
        save()
    }

    func applyRetention(isPro: Bool) {
        self.isPro = isPro
        // Re-publish so views bound to visibleEntries refresh on tier change.
        objectWillChange.send()
    }

    // MARK: - Insights

    struct Insights {
        var total: Int
        var counts: [Sentiment: Int]
        var averageLikelihood: Double

        func share(of sentiment: Sentiment) -> Double {
            guard total > 0 else { return 0 }
            return Double(counts[sentiment, default: 0]) / Double(total)
        }
    }

    var insights: Insights {
        var counts: [Sentiment: Int] = [:]
        var likelihoodTotal = 0.0
        for entry in entries {
            counts[entry.prediction.sentiment, default: 0] += 1
            likelihoodTotal += entry.prediction.likelihood
        }
        return Insights(
            total: entries.count,
            counts: counts,
            averageLikelihood: entries.isEmpty ? 0 : likelihoodTotal / Double(entries.count)
        )
    }

    // MARK: - Persistence

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // History is a convenience, not the product. A failed write should
            // never interrupt someone mid-question.
            #if DEBUG
            print("[HistoryStore] save failed: \(error)")
            #endif
        }
    }
}
