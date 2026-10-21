import DrumAI
import DrumAnalysis
import DrumAudio
import DrumCore
import AVFoundation
import DrumLibrary
import Foundation
import SwiftData
import SwiftUI

enum InputMode: String, CaseIterable, Identifiable {
    case pad, eDrum, touch, listenOnly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pad: L("Pad (micro)", "Pad (mic)")
        case .eDrum: L("Trống điện", "E-drum kit")
        case .touch: L("Gõ màn hình", "Tap screen")
        case .listenOnly: L("Chỉ xem", "View only")
        }
    }
}

struct RunSample: Identifiable {
    let id = UUID()
    let time: Double
    let ms: Double?
    let grade: Grade
}

enum NotationDisplay: String, CaseIterable, Identifiable {
    case page, scroll
    var id: String { rawValue }
    var title: String { self == .page ? L("Trang", "Page") : L("Cuộn", "Scroll") }
}


@MainActor
final class PracticeViewModel: ObservableObject {
    @Published var exercise: Exercise { didSet { if !isPlaying { flipped = false; loopBars = nil; autoLearn = nil } } }
    @Published var settings: MetronomeSettings
    @Published var mode: InputMode = .pad
    @Published var display: NotationDisplay = .page
    @Published var durationSeconds: Double = 60
    @Published var flipped = false
    /// Bars to loop (1-based); nil = the whole exercise.
    @Published var loopBars: ClosedRange<Int>?
    /// Set when "Học tự động" is running.
    @Published var autoLearn: AutoLearnState?
    @Published private(set) var lastDiagnosis: TimingDiagnosis?
    /// (seconds into the run, offset ms, grade) of the last run, for the analysis chart.
    @Published private(set) var lastSamples: [RunSample] = []
    private let listenPlayer = DrumPlayer()
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
    /// When set, this run is a level test: tempo, length and scoring are locked.
    let testItem: LevelTestItem?
    var modelContext: ModelContext?
    static let countInBars = 1

    private var source: (any HitSource)?
    private var matcher: HitMatcher?
    private var byRepeatAndNote: [Int: [Int: Int]] = [:]
    private var tasks: [Task<Void, Never>] = []
    private var startedAt = Date()
    private var reportDelay: TimeInterval = 0
    private var observers: [NSObjectProtocol] = []
    /// Set when a run plays without mic scoring (click coming out of the speaker).
    @Published private(set) var scoringOffReason: String?

    init(exercise: Exercise, voiceBank: CountVoiceBank, testItem: LevelTestItem? = nil) {
        self.exercise = exercise
        self.testItem = testItem
        var saved = SettingsStore.loadMetronome() ?? MetronomeSettings(bpm: 70, pattern: .eighths, accentBeatOne: true)
        if let testItem {
            saved.bpm = testItem.bpm
            durationSeconds = testItem.duration
        }
        settings = saved
        engine = MetronomeEngine(voiceBank: voiceBank, settings: saved)
    }

    /// The exercise as played: hands flipped when FLIP is on, cut to the looped bars.
    var playedExercise: Exercise {
        var e = flipped ? exercise.flippedHands() : exercise
        if let loopBars { e = e.slice(bars: loopBars) }
        return e
    }

    /// Play the exercise once with synthesized drums so you hear it before playing it.
    /// Swing for this exercise: the setting, or straight when the exercise has 16ths, triplets or an x/8 meter.
    var swing: Double { Swing.effective(settings.swing, for: playedExercise) }

    /// Screen tap in L("Gõ màn hình", "Tap screen") mode.
    func tap(_ voice: Voice?) { (source as? TouchHitSource)?.tap(voice) }

    func listen() {
        try? AudioSessionConfig.activate()
        try? listenPlayer.play(playedExercise, bpm: settings.bpm, countInBars: 1, swing: swing)
    }

    func stopListening() { listenPlayer.stop() }

    // MARK: Auto-learn

    struct AutoLearnState {
        var plan: AutoLearnPlan
        var stepIndex = 0
        var tempo: AdaptiveTempo
        var lastScore: Double?
        var step: AutoLearnPlan.Step? { stepIndex < plan.steps.count ? plan.steps[stepIndex] : nil }
        var finished: Bool { step == nil }
    }

    func startAutoLearn() {
        let target = max(Int(settings.bpm), exercise.suggestedTempo.upperBound > 300 ? 120 : exercise.suggestedTempo.upperBound)
        autoLearn = AutoLearnState(plan: AutoLearnPlan(exercise: exercise), tempo: AdaptiveTempo(target: target))
        applyAutoLearnStep()
    }

    func stopAutoLearn() {
        autoLearn = nil
        loopBars = nil
        settings.volume = SettingsStore.loadMetronome()?.volume ?? 1
    }

    private func applyAutoLearnStep() {
        guard let state = autoLearn, let step = state.step else { return }
        loopBars = step.bars.lowerBound == 1 && step.bars.upperBound == exercise.bars ? nil : step.bars
        settings.bpm = Double(state.tempo.bpm)
        settings.volume = step.withClick ? (SettingsStore.loadMetronome()?.volume ?? 1) : 0
        let passSeconds = playedExercise.lengthInBeats.doubleValue * 60 / settings.bpm
        durationSeconds = max(20, passSeconds * 4)
    }

    /// After a run in auto-learn: adjust tempo; a step is done once it is played above 90% at the target tempo.
    private func recordAutoLearn(score: Double) {
        guard var state = autoLearn else { return }
        state.lastScore = score
        let atTargetBefore = state.tempo.atTarget
        state.tempo.record(score: score)
        if score > 90, atTargetBefore {
            state.stepIndex += 1
            state.tempo = AdaptiveTempo(target: state.tempo.target)
        }
        autoLearn = state
        applyAutoLearnStep()
    }

    /// Timeline of the current run, or a preview of the first passes when stopped.
    var displayTimeline: Timeline {
        timeline.flatMap { isPlaying || !results.isEmpty ? $0 : nil }
            ?? Timeline(exercise: playedExercise, bpm: settings.bpm, repeats: 2, countInBars: Self.countInBars, swing: swing)
    }

    var exerciseSeconds: Double { exercise.lengthInBeats.doubleValue * 60 / settings.bpm }

    var showHeadphoneWarning: Bool { mode == .pad && AudioSessionConfig.isUsingSpeaker && !isPlaying }

    func play() {
        stop(save: false)
        error = nil
        results = [:]
        extraHits = 0
        recent = []
        liveScore = nil
        finishedStats = nil
        matcher = nil
        rules = testItem == nil ? SettingsStore.scoring : ScoringRules()
        if let testItem { settings.bpm = testItem.bpm; durationSeconds = testItem.duration; flipped = false }

        let repeats = max(1, Int((durationSeconds / exerciseSeconds).rounded(.up)))
        var s = settings
        s.timeSignature = exercise.timeSignature
        s.swing = swing
        let tl = Timeline(exercise: playedExercise, bpm: s.bpm, repeats: repeats, countInBars: Self.countInBars, swing: s.swing)
        timeline = tl
        byRepeatAndNote = [:]
        for n in tl.notes { byRepeatAndNote[n.repeatIndex, default: [:]][n.noteIndex] = n.index }

        do {
            try AudioSessionConfig.activate()
            // The mic would hear the click from the speaker: blanking around clicks also drops on-time strokes,
            // so with the speaker the run is played without scoring instead of being scored wrongly.
            scoringOffReason = mode == .pad && AudioSessionConfig.isUsingSpeaker
                ? L("Đang phát ra loa nên app không chấm điểm (micro sẽ nghe lẫn tiếng click). Cắm tai nghe để được chấm.", "Sound is coming from the speaker, so the app won't score this run (the mic would pick up the click). Plug in headphones to be scored.") : nil
            source = scoringOffReason == nil ? HitSources.make(for: mode) : nil
            reportDelay = source?.reportDelay ?? 0
            try source?.start()
            try engine.start(settings: s)
        } catch {
            self.error = L("Không mở được âm thanh/MIDI: \(error.localizedDescription)", "Couldn't open audio/MIDI: \(error.localizedDescription)")
            source?.stop()
            source = nil
            return
        }
        isPlaying = true
        startedAt = Date()
        observeInterruptions()

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
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        source?.stop()
        source = nil
        let wasPlaying = isPlaying
        engine.stop()
        isPlaying = false
        // A run on the speaker is not scored (see play()), so it is not saved: it would count every note as missed.
        guard save, wasPlaying, let timeline, let matcher, mode != .listenOnly, scoringOffReason == nil else { return }

        // Count only notes whose time has come (stopping early does not punish the rest).
        let elapsed = HostClock.now() - matcher.beatZero - reportDelay
        let played = timeline.notes.filter { $0.time + matcher.window <= elapsed }
        guard !played.isEmpty else { return }
        var finalResults = results
        for n in played where finalResults[n.index] == nil { finalResults[n.index] = .missed }
        let stats = SessionStats(results: finalResults, notes: played, extraHits: extraHits, rules: rules)
        lastSamples = played.map { n in
            let r = finalResults[n.index] ?? .missed
            return RunSample(time: n.time - timeline.beatTime(Rational(0, 1)), ms: r.offset.map { $0 * 1000 }, grade: rules.grade(r))
        }
        lastDiagnosis = TimingDiagnosis(samples: played.compactMap { n in finalResults[n.index]?.offset.map { (n.time, $0 * 1000) } })
        finishedStats = stats
        recordAutoLearn(score: stats.score)
        if let ctx = modelContext {
            let session = PracticeSession(date: startedAt, exerciseId: exercise.id.uuidString, title: exercise.title,
                                       skill: exercise.source, bpm: settings.bpm, seconds: Date().timeIntervalSince(startedAt),
                                       mode: mode.rawValue, goodWindowMs: rules.goodWindow * 1000, stats: stats,
                                          isLevelTest: testItem != nil, levelTestId: testItem?.id)
            ctx.insert(session)
            try? ctx.save()
            lastSession = session
            ReminderScheduler.schedule(today: nil, practicedToday: true)
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
                                 window: HitMatcher.window(for: timeline.notes, goodWindow: rules.goodWindow))
        }
        guard var m = matcher else { return }
        if let zero = engine.beatZeroHostTime { m.resync(beatZero: zero) }
        for (index, result) in m.expire(upTo: HitMatcher.expiryCutoff(now: now, reportDelay: reportDelay)) { record(index, result) }
        matcher = m
        if now - m.beatZero > timeline.duration + 0.2 + reportDelay { stop() }
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

    /// Headphones plugged/unplugged, a call or Siri: the audio graph stops, so stop the run without saving it.
    private func observeInterruptions() {
        let names: [Notification.Name] = [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                                          .AVAudioEngineConfigurationChange]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                MainActor.assumeIsolated {
                    guard let self, self.isPlaying else { return }
                    if name == AVAudioSession.routeChangeNotification,
                       let raw = reasonRaw, let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                       ![.newDeviceAvailable, .oldDeviceUnavailable].contains(reason) { return }
                    self.stop(save: false)
                    self.error = L("Âm thanh bị gián đoạn (đổi tai nghe/loa hoặc cuộc gọi). Lần chơi này không được lưu — bấm Bắt đầu để chơi lại.", "Audio was interrupted (headphones/speaker change or a call). This run wasn't saved. Tap Start to play again.")
                }
            }
        }
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
