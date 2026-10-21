import Foundation

/// Runs a structured practice session (warm-up → main → fun) segment by segment.
public struct SessionRunner: Sendable {
    public struct Segment: Sendable, Equatable {
        public let title: String
        public let minutes: Double
        public init(title: String, minutes: Double) { self.title = title; self.minutes = minutes }
    }

    public let segments: [Segment]
    private var index = 0
    private var elapsedInSegment: TimeInterval = 0
    private var played: TimeInterval = 0

    public init(segments: [Segment]) { self.segments = segments.filter { $0.minutes > 0 } }

    public var current: Segment? { index < segments.count ? segments[index] : nil }
    public var currentIndex: Int { index }
    public var isFinished: Bool { current == nil }
    public var remaining: TimeInterval { current.map { $0.minutes * 60 - elapsedInSegment } ?? 0 }
    public var completedMinutes: Double { played / 60 }

    /// Advance the clock; returns true when at least one segment finished.
    public mutating func tick(_ dt: TimeInterval) -> Bool {
        var left = dt, advanced = false
        while left > 0, let seg = current {
            let room = seg.minutes * 60 - elapsedInSegment
            let used = min(left, room)
            elapsedInSegment += used
            played += used
            left -= used
            if elapsedInSegment >= seg.minutes * 60 - 1e-9 {
                index += 1
                elapsedInSegment = 0
                advanced = true
            }
        }
        return advanced
    }

    public mutating func skip() {
        guard current != nil else { return }
        index += 1
        elapsedInSegment = 0
    }
}
