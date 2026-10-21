import DrumAI
import DrumAnalysis
import DrumAudio
import DrumCore
import Foundation
import SwiftData
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

extension Grade {
    var color: Color {
        switch self {
        case .good: .green
        case .early, .late: .orange
        case .missed: .red
        }
    }
}

@MainActor
final class PracticeViewModel: ObservableObject {
    @Published var exercise: Exercise { didSet { if !isPlaying { flipped = false } } }
    @Published var settings: MetronomeSettings
    @Published var mode: InputMode = .pad
    @Published var display: NotationDisplay = .page
    @Published var durationSeconds: Double = 60
    @Published var flipped = false
    @Published var rules = SettingsStore.scoring
    @Published private(set) var isPlaying = false
    @Published private(set) var timeline: Timeline?
    /// Results keyed by timeline index.
    @Published private(set) var results: [Int: NoteResult] = [:]
    @Published private(set) var extraHits = 0
    /// Last offsets (ms) with their grade, newest last, for the timing strip.
    @Published private(set) var recent: [(ms: Double, grade: Grade)] = []
    @Published private(set) var liveScore: Double?
    @Published var finishedStats: SessionStats?
    private(set) var lastSession: PracticeSession?
    @Published var error: String?

    let engine: MetronomeEngine
    var modelContext: ModelContext?
    static let countInBars = 1

    private var source: (any HitSource)?
    private var matcher: HitMatcher?
    private var byRepeatAndNote: [Int: [Int: Int]] = [:]
    private var tasks: [Task<Void, Never>] = []
    private var startedAt = Date()

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
        timeline.flatMap { isPlaying || !results.isEmpty ? $0 : nil }
            ?? Timeline(exercise: playedExercise, bpm: settings.bpm, repeats: 2, countInBars: Self.countInBars)
    }

    var exerciseSeconds: Double { exercise.lengthInBeats.doubleValue * 60 / settings.bpm }

    var showHeadphoneWarning: Bool { mode == .pad && AudioSessionConfig.isUsingSpeaker }

    func play() {
        stop(save: false)
        error = nil
        results = [:]
        extraHits = 0
        recent = []
        liveScore = nil
        finishedStats = nil
        matcher = nil
        rules = SettingsStore.scoring

        let repeats = max(1, Int((durationSeconds / exerciseSeconds).rounded(.up)))
        var s = settings
        s.timeSignature = exercise.timeSignature
        let tl = Timeline(exercise: playedExercise, bpm: s.bpm, repeats: repeats, countInBars: Self.countInBars)
        timeline = tl
        byRepeatAndNote = [:]
        for n in tl.notes { byRepeatAndNote[n.repeatIndex, default: [:]][n.noteIndex] = n.index }

        do {
            try AudioSessionConfig.activate()
            source = HitSources.make(for: mode)
            try source?.start()
            try engine.start(settings: s)
        } catch {
            self.error = "Không mở được âm thanh/MIDI: \(error.localizedDescription)"
            source?.stop()
            source = nil
            return
        }
        isPlaying = true
        startedAt = Date()

        if let hits = source?.hits {
            tasks.append(Task { [weak self] in
                for await hit in hits { self?.handle(hit) }
            })
        }
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(30))
                guard let self, self.isPlaying else { return }
                self.tick()
            }
        })
    }

    func stop(save: Bool = true) {
        tasks.forEach { $0.cancel() }
        tasks = []
        source?.stop()
        source = nil
        let wasPlaying = isPlaying
        engine.stop()
        isPlaying = false
        guard save, wasPlaying, let timeline, let matcher, mode != .listenOnly else { return }

        // Count only notes whose time has come (stopping early does not punish the rest).
        let elapsed = HostClock.now() - matcher.beatZero
        let played = timeline.notes.filter { $0.time - matcher.window <= elapsed }
        guard !played.isEmpty else { return }
        var finalResults = results
        for n in played where finalResults[n.index] == nil { finalResults[n.index] = .missed }
        let stats = SessionStats(results: finalResults, notes: played, extraHits: extraHits, rules: rules)
        finishedStats = stats
        if let ctx = modelContext {
            let session = PracticeSession(date: startedAt, exerciseId: exercise.id.uuidString, title: exercise.title,
                                       skill: exercise.source, bpm: settings.bpm, seconds: Date().timeIntervalSince(startedAt),
                                       mode: mode.rawValue, goodWindowMs: rules.goodWindow * 1000, stats: stats)
            ctx.insert(session)
            try? ctx.save()
            lastSession = session
        }
    }

    /// Input for the Rockschool-style assessment of the last run.
    func assessmentInput(for stats: SessionStats) -> AssessmentInput {
        AssessmentInput(exerciseTitle: exercise.title, skill: exercise.source, grade: max(1, SettingsStore.currentGrade),
                        bpm: settings.bpm, targetBpm: exercise.suggestedTempo.upperBound, stats: stats, recentHistory: [],
                        mode: mode.rawValue)
    }

    private func tick() {
        let now = HostClock.now()
        guard let timeline else { return }
        if matcher == nil, let zero = engine.beatZeroHostTime {
            matcher = HitMatcher(expected: timeline.notes, beatZero: zero,
                                 window: max(HitMatcher.defaultWindow(for: timeline.notes), rules.goodWindow * 1.5))
            if let mic = source as? MicOnsetSource, AudioSessionConfig.isUsingSpeaker {
                mic.setSuppressWindows(clickWindows(beatZero: zero, duration: timeline.duration))
            }
        }
        guard var m = matcher else { return }
        for (index, result) in m.expire(upTo: now) { record(index, result) }
        matcher = m
        if now - m.beatZero > timeline.duration + 0.2 { stop() }
    }

    private func handle(_ hit: Hit) {
        guard var m = matcher else { return }
        if let matches = m.consume(hit) {
            for match in matches { record(match.noteIndex, match.result) }
        } else if hit.time >= m.beatZero {
            extraHits = m.extraHits.count
        }
        matcher = m
        updateScore()
    }

    private func record(_ index: Int, _ result: NoteResult) {
        results[index] = result
        let g = rules.grade(result)
        if let o = result.offset {
            recent.append((o * 1000, g))
            if recent.count > 16 { recent.removeFirst(recent.count - 16) }
        }
        updateScore()
    }

    private func updateScore() {
        let graded = Array(results.values)
        guard !graded.isEmpty else { return }
        liveScore = rules.score(graded, totalNotes: graded.count, extraHits: extraHits)
    }

    /// Times when the metronome is audible, so the mic ignores the click when it plays through the speaker.
    private func clickWindows(beatZero: TimeInterval, duration: TimeInterval) -> [ClosedRange<TimeInterval>] {
        let sr = 48_000.0
        var s = settings
        s.timeSignature = exercise.timeSignature
        return ClickSchedule.events(settings: s, sampleRate: sr, from: 0, to: Int64((duration + 1) * sr))
            .filter { if case .voice = $0.kind { false } else { true } }
            .map { let t = beatZero + Double($0.sampleTime) / sr; return (t - 0.004)...(t + 0.035) }
    }

    // MARK: Display helpers

    /// Beats since the end of the count-in at `hostTime`; negative during count-in; nil when stopped.
    func beat(atHostTime hostTime: TimeInterval) -> Double? {
        guard isPlaying, let zero = engine.beatZeroHostTime else { return nil }
        let countIn = exercise.timeSignature.beatsInQuarters.doubleValue * Double(Self.countInBars)
        return (hostTime - zero) * settings.bpm / 60 - countIn
    }

    func currentRepeat(beat: Double?) -> Int {
        guard let beat, beat > 0 else { return 0 }
        return Int(beat / exercise.lengthInBeats.doubleValue)
    }

    /// Result for an exercise note in the given pass.
    func result(noteIndex: Int, repeat r: Int) -> NoteResult? {
        byRepeatAndNote[r]?[noteIndex].flatMap { results[$0] }
    }

    func color(noteIndex: Int, repeat r: Int) -> Color? {
        result(noteIndex: noteIndex, repeat: r).map { rules.grade($0).color }
    }

    /// Offset in ms for orange (early/late) notes, to draw the mark before/after the note.
    func orangeOffsetMs(noteIndex: Int, repeat r: Int) -> Double? {
        guard let res = result(noteIndex: noteIndex, repeat: r), let o = res.offset else { return nil }
        let g = rules.grade(res)
        return g == .early || g == .late ? o * 1000 : nil
    }
}
