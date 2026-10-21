import DrumCore
import Foundation

/// Judges a spoken count syllable by syllable while it happens, then scores it and says what to work on.
public struct CountJudge: Sendable {
    public enum Verdict: Sendable, Equatable { case onTime, early, late }

    public struct Mark: Sendable, Equatable {
        public let label: String
        public let offsetMs: Double
        public let verdict: Verdict
    }

    public struct Summary: Sendable, Equatable {
        public let onTime, early, late, missed: Int
        /// 0–100: on time counts fully, early/late half, missed nothing.
        public let score: Int
        /// Most important first; at most three.
        public let tips: [String]
    }

    /// Within this many ms of the click a syllable counts as on time.
    public static let onTimeMs = 50.0

    private let expected: [(time: TimeInterval, label: String)]
    private let window: TimeInterval
    private var heard: [Int: TimeInterval] = [:]

    public init(expected: [(time: TimeInterval, label: String)]) {
        self.expected = expected.sorted { $0.time < $1.time }
        let slot = zip(self.expected, self.expected.dropFirst()).map { $1.time - $0.time }.min() ?? 0.5
        window = min(slot * 0.45, 0.2)
    }

    /// Match a detected syllable start to the nearest syllable not yet said; nil when it belongs to none.
    public mutating func hear(_ onset: TimeInterval) -> Mark? {
        let best = expected.indices.filter { heard[$0] == nil && abs(expected[$0].time - onset) <= window }
            .min { abs(expected[$0].time - onset) < abs(expected[$1].time - onset) }
        guard let i = best else { return nil }
        heard[i] = onset
        return mark(i, onset)
    }

    private func mark(_ i: Int, _ onset: TimeInterval) -> Mark {
        let ms = (onset - expected[i].time) * 1000
        return Mark(label: expected[i].label, offsetMs: ms, verdict: abs(ms) <= Self.onTimeMs ? .onTime : (ms < 0 ? .early : .late))
    }

    /// Everything due before `now` (syllables whose window has closed unsaid are missed).
    public func summary(until now: TimeInterval) -> Summary {
        let due = expected.indices.filter { expected[$0].time + window < now || heard[$0] != nil }
        let marks = due.compactMap { i in heard[i].map { (i, mark(i, $0)) } }
        let missedIdx = due.filter { heard[$0] == nil }
        let onTime = marks.filter { $0.1.verdict == .onTime }.count
        let early = marks.filter { $0.1.verdict == .early }.count
        let late = marks.count - onTime - early
        let total = max(due.count, 1)
        let score = Int((Double(onTime * 100 + (early + late) * 50) / Double(total)).rounded())
        return Summary(onTime: onTime, early: early, late: late, missed: missedIdx.count, score: due.isEmpty ? 0 : score,
                       tips: tips(marks: marks, missed: missedIdx, total: total))
    }

    private static func group(_ label: String) -> String { Int(label) != nil ? L("số", "numbers") : "\"\(label)\"" }

    private func tips(marks: [(Int, Mark)], missed: [Int], total: Int) -> [String] {
        var issues: [(severity: Double, text: String)] = []

        // A syllable that is consistently early or late (numbers grouped together).
        var byGroup: [String: [Double]] = [:]
        for (_, m) in marks { byGroup[Self.group(m.label), default: []].append(m.offsetMs) }
        if let (name, offsets) = byGroup.max(by: { abs(mean($0.value)) < abs(mean($1.value)) }), abs(mean(offsets)) > 35 {
            let ms = Int(abs(mean(offsets)).rounded())
            issues.append((abs(mean(offsets)), mean(offsets) > 0
                ? L("Bạn nói \(name) trễ trung bình \(ms) ms. Nghĩ âm đó nằm đúng giữa hai click và nói sớm hơn một chút.", "You say \(name) \(ms) ms late on average. Think of it sitting exactly between two clicks and say it a little earlier.")
                : L("Bạn nói \(name) sớm trung bình \(ms) ms. Đừng vội, chờ đúng chỗ của nó rồi mới nói.", "You say \(name) \(ms) ms early on average. Don't rush; wait for its place before saying it.")))
        }

        // Missed syllables, naming the one missed most.
        if !missed.isEmpty {
            var counts: [String: Int] = [:], order: [String] = []
            for i in missed {
                let g = Self.group(expected[i].label)
                if counts[g] == nil { order.append(g) }
                counts[g, default: 0] += 1
            }
            // Most missed; on a tie, the one missed first (dictionary order would make the advice change run to run).
            let worst = order.max { counts[$0]! < counts[$1]! || (counts[$0]! == counts[$1]! && order.firstIndex(of: $0)! > order.firstIndex(of: $1)!) }!
            issues.append((Double(missed.count) / Double(total) * 400,
                           L("App không nghe thấy \(missed.count) âm (hay sót nhất: \(worst)). Nói to và rõ từng âm, kể cả âm nhẹ.", "The app didn't hear \(missed.count) syllables (most often \(worst)). Say every syllable clearly, even the soft ones.")))
        }

        // Rushing or dragging: how far the offset drifts from the first heard syllable to the last.
        if marks.count >= 6 {
            let xs = marks.map { expected[$0.0].time }, ys = marks.map { $0.1.offsetMs }
            let mx = mean(xs), my = mean(ys)
            let den = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
            let slope = den > 0 ? zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) } / den : 0
            let change = slope * ((xs.last ?? 0) - (xs.first ?? 0))
            if abs(change) > 60 {
                issues.append((abs(change), change < 0
                    ? L("Bạn đếm nhanh dần (về cuối sớm hơn \(Int((-change).rounded())) ms). Thả lỏng, bám theo click thay vì đếm theo cảm giác.", "You speed up (\(Int((-change).rounded())) ms earlier by the end). Relax and follow the click rather than your feel.")
                    : L("Bạn đếm chậm dần (về cuối trễ hơn \(Int(change.rounded())) ms). Giữ hơi đều và đếm liền một mạch.", "You slow down (\(Int(change.rounded())) ms later by the end). Keep your breath even and count in one flow.")))
            }
            let sd = (ys.reduce(0) { $0 + ($1 - my) * ($1 - my) } / Double(ys.count - 1)).squareRoot()
            if sd > 40 {
                issues.append((sd, L("Khoảng cách giữa các âm chưa đều (dao động ±\(Int(sd.rounded())) ms). Đếm chậm lại 8 BPM cho thật đều rồi tăng dần.", "The gaps between syllables vary (±\(Int(sd.rounded())) ms). Drop 8 BPM until it's even, then build back up.")))
            }
        }

        let top = issues.sorted { $0.severity > $1.severity }.prefix(3).map(\.text)
        return top.isEmpty ? [L("Rất đều! Thử giai đoạn tiếp theo hoặc tăng tempo 4 BPM.", "Very even! Try the next phase or raise the tempo by 4 BPM.")] : Array(top)
    }

    private func mean(_ v: [Double]) -> Double { v.isEmpty ? 0 : v.reduce(0, +) / Double(v.count) }
}

/// One counting-coach run, kept for the AI teacher's weekly report.
public struct CountRecord: Codable, Sendable, Equatable {
    public let date: Date
    /// "along", "fade" or "alone".
    public let phase: String
    /// How the bar was counted, e.g. "1 & 2 &".
    public let style: String
    public let bpm: Double
    public let score: Int
    public let onTime, early, late, missed: Int
    public let tips: [String]

    public init(date: Date, phase: String, style: String, bpm: Double, summary: CountJudge.Summary) {
        self.date = date
        self.phase = phase
        self.style = style
        self.bpm = bpm
        score = summary.score
        onTime = summary.onTime
        early = summary.early
        late = summary.late
        missed = summary.missed
        tips = summary.tips
    }
}
