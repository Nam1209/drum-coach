import Foundation

public struct TimedNote: Sendable, Hashable {
    public let index: Int
    public let note: NoteEvent
    /// Seconds from beat zero (start of count-in).
    public let time: TimeInterval
}

/// Converts an exercise's beat positions to seconds for one run (count-in + repeats) at a fixed tempo.
public struct Timeline: Sendable {
    public let bpm: Double
    public let notes: [TimedNote]
    public let duration: TimeInterval
    private let countInBeats: Rational

    public init(exercise: Exercise, bpm: Double, repeats: Int, countInBars: Int) {
        self.bpm = bpm
        let barBeats = exercise.timeSignature.beatsInQuarters
        countInBeats = barBeats * Rational(countInBars, 1)
        let exerciseBeats = exercise.lengthInBeats
        let secondsPerBeat = 60.0 / bpm

        var timed: [TimedNote] = []
        for rep in 0..<max(repeats, 0) {
            let offset = countInBeats + exerciseBeats * Rational(rep, 1)
            for note in exercise.notes {
                timed.append(TimedNote(index: 0, note: note, time: (offset + note.position).doubleValue * secondsPerBeat))
            }
        }
        timed.sort { $0.time < $1.time }
        notes = timed.enumerated().map { TimedNote(index: $0.offset, note: $0.element.note, time: $0.element.time) }
        duration = (countInBeats + exerciseBeats * Rational(max(repeats, 0), 1)).doubleValue * secondsPerBeat
    }

    /// Seconds from beat zero for a beat position measured from the end of the count-in.
    public func beatTime(_ beat: Rational) -> TimeInterval {
        (countInBeats + beat).doubleValue * 60.0 / bpm
    }
}
