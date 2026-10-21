import DrumAudio
import DrumCore
import Foundation
import SwiftUI

enum InputMode: String, CaseIterable, Identifiable {
    case pad, eDrum, listenOnly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pad: "Pad (micro)"
        case .eDrum: "Trống điện"
        case .listenOnly: "Chỉ xem"
        }
    }
}

enum NotationDisplay: String, CaseIterable, Identifiable {
    case page, scroll
    var id: String { rawValue }
    var title: String { self == .page ? "Trang" : "Cuộn" }
}

@MainActor
final class PracticeViewModel: ObservableObject {
    @Published var exercise: Exercise { didSet { if !isPlaying { flipped = false } } }
    @Published var settings: MetronomeSettings
    @Published var mode: InputMode = .pad
    @Published var display: NotationDisplay = .page
    @Published var durationSeconds: Double = 60
    @Published var flipped = false
    @Published private(set) var isPlaying = false
    @Published private(set) var timeline: Timeline?

    let engine: MetronomeEngine
    static let countInBars = 1
    private var stopTask: Task<Void, Never>?

    init(exercise: Exercise, voiceBank: CountVoiceBank) {
        self.exercise = exercise
        let saved = SettingsStore.loadMetronome() ?? MetronomeSettings(bpm: 70, pattern: .eighths, accentBeatOne: true)
        settings = saved
        engine = MetronomeEngine(voiceBank: voiceBank, settings: saved)
    }

    /// The exercise as played (hands flipped when FLIP is on).
    var playedExercise: Exercise { flipped ? exercise.flippedHands() : exercise }

    /// Timeline of the current run, or a preview of the first passes when stopped.
    var displayTimeline: Timeline {
        timeline.flatMap { isPlaying ? $0 : nil }
            ?? Timeline(exercise: playedExercise, bpm: settings.bpm, repeats: 2, countInBars: Self.countInBars)
    }

    var exerciseSeconds: Double { exercise.lengthInBeats.doubleValue * 60 / settings.bpm }

    func play() throws {
        stop()
        let repeats = max(1, Int((durationSeconds / exerciseSeconds).rounded(.up)))
        var s = settings
        s.timeSignature = exercise.timeSignature
        timeline = Timeline(exercise: playedExercise, bpm: s.bpm, repeats: repeats, countInBars: Self.countInBars)
        try AudioSessionConfig.activate()
        try engine.start(settings: s)
        isPlaying = true
        let total = timeline!.duration + 0.3
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(total))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        engine.stop()
        isPlaying = false
    }

    /// Beats (quarter notes) since the end of the count-in at `hostTime`; negative during count-in; nil when stopped.
    func beat(atHostTime hostTime: TimeInterval) -> Double? {
        guard isPlaying, let zero = engine.beatZeroHostTime else { return nil }
        let countIn = exercise.timeSignature.beatsInQuarters.doubleValue * Double(Self.countInBars)
        return (hostTime - zero) * settings.bpm / 60 - countIn
    }
}
