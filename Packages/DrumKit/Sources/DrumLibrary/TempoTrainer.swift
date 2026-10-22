/// Gradual tempo change ("speed trainer"): move `step` BPM toward `target` every `everyBars` bars,
/// optionally only when the mean accuracy over those bars reaches `requireAccuracy`.
public struct TempoRamp: Codable, Sendable, Equatable {
    public var start: Double
    public var target: Double
    public var step: Double
    public var everyBars: Int
    public var requireAccuracy: Double?

    public init(start: Double, target: Double, step: Double, everyBars: Int, requireAccuracy: Double?) {
        self.start = start
        self.target = target
        self.step = step
        self.everyBars = everyBars
        self.requireAccuracy = requireAccuracy
    }

    /// The user's comfortable range: 50 → 90 BPM, +2 every 4 bars when ≥ 90% accurate.
    public static let `default` = TempoRamp(start: 50, target: 90, step: 2, everyBars: 4, requireAccuracy: 0.9)
}

public struct TempoTrainer: Sendable {
    public let ramp: TempoRamp
    public private(set) var currentBpm: Double
    private var barsAtTempo = 0
    private var accuracies: [Double] = []

    public init(_ ramp: TempoRamp) {
        self.ramp = ramp
        currentBpm = ramp.start
    }

    /// Report a finished bar; returns the BPM for the next bar.
    public mutating func barCompleted(accuracy: Double?) -> Double {
        barsAtTempo += 1
        if let accuracy { accuracies.append(accuracy) }
        guard barsAtTempo >= max(ramp.everyBars, 1) else { return currentBpm }

        let mean = accuracies.isEmpty ? nil : accuracies.reduce(0, +) / Double(accuracies.count)
        let accurateEnough = ramp.requireAccuracy.map { req in (mean ?? 0) >= req } ?? true
        barsAtTempo = 0
        accuracies.removeAll()
        guard accurateEnough else { return currentBpm }

        let direction: Double = ramp.target >= currentBpm ? 1 : -1
        let next = currentBpm + direction * abs(ramp.step)
        currentBpm = direction > 0 ? min(next, ramp.target) : max(next, ramp.target)
        return currentBpm
    }
}
