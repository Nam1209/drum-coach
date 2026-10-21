import DrumAnalysis
import DrumAudio
import DrumCore
import SwiftData
import SwiftUI

struct PracticeView: View {
    @StateObject private var model: PracticeViewModel
    @State private var showSheet = false
    @State private var showCalibration = false
    private let voiceBank: CountVoiceBank
    @Environment(\.modelContext) private var modelContext
    @State private var taps: [Date] = []
    private let exercises: [Exercise]

    init(exercises: [Exercise], voiceBank: CountVoiceBank) {
        self.exercises = exercises
        self.voiceBank = voiceBank
        _model = StateObject(wrappedValue: PracticeViewModel(exercise: exercises[0], voiceBank: voiceBank))
    }

    var body: some View {
        TimelineView(.animation(paused: !model.isPlaying)) { context in
            let now = HostClock.now()
            let beat = model.beat(atHostTime: now)
            let pass = model.currentRepeat(beat: beat)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if model.showHeadphoneWarning {
                        Label("Nên dùng tai nghe: micro đang nghe cả tiếng click từ loa, app sẽ bỏ qua tiếng gõ trùng lúc click.",
                              systemImage: "headphones")
                            .font(.callout).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.15)))
                    }
                    NotationView(exercise: model.playedExercise, display: model.display, beat: beat,
                                 noteColor: { model.color(noteIndex: $0, repeat: pass) },
                                 orangeOffsetMs: { model.orangeOffsetMs(noteIndex: $0, repeat: pass) })
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    RLStripView(timeline: model.displayTimeline, exercise: model.playedExercise,
                                countMode: model.settings.voiceCount ?? .eighths, beat: beat,
                                noteColor: { tn in model.results[tn.index].map { model.rules.grade($0).color } })
                    HStack(alignment: .center, spacing: 20) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Score").font(.caption).foregroundStyle(.secondary)
                            Text(model.liveScore.map { "\(Int($0.rounded()))%" } ?? "–")
                                .font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                        }
                        .frame(width: 120, alignment: .leading)
                        TimingStrip(recent: model.recent)
                    }
                    controls
                    if let error = model.error { Text(error).foregroundStyle(.red) }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showSheet) { MetronomeSheet(settings: $model.settings) }
        .sheet(isPresented: $showCalibration) { CalibrationView(voiceBank: voiceBank) }
        .sheet(item: $model.finishedStats) { stats in
            ResultsView(stats: stats, title: model.exercise.title, bpm: model.settings.bpm,
                        input: model.assessmentInput(for: stats), session: model.lastSession)
        }
        .onAppear { model.modelContext = modelContext }
        .onChange(of: model.settings) { _, new in SettingsStore.saveMetronome(new) }
        .onDisappear { model.stop() }
    }

    private var header: some View {
        HStack {
            Menu {
                ForEach(exercises) { ex in Button(ex.title) { model.stop(); model.exercise = ex } }
            } label: {
                Label(model.exercise.title, systemImage: "music.note.list").font(.title2.bold())
            }
            Spacer()
            Picker("Hiển thị", selection: $model.display) {
                ForEach(NotationDisplay.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 180)
            Button { showCalibration = true } label: { Image(systemName: "dot.radiowaves.left.and.right") }
                .buttonStyle(.bordered).accessibilityLabel("Hiệu chỉnh độ trễ")
        }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                circle("minus") { model.settings.bpm = max(30, model.settings.bpm - 1) }
                VStack(spacing: 0) {
                    Text("\(Int(model.settings.bpm))").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("BPM").foregroundStyle(.secondary)
                }
                .frame(minWidth: 130)
                circle("plus") { model.settings.bpm = min(300, model.settings.bpm + 1) }
                Button("Tap") { tapTempo() }.buttonStyle(.bordered)
                Button { showSheet = true } label: { Image(systemName: "slider.horizontal.3") }.buttonStyle(.bordered)
            }
            .disabled(model.isPlaying)
            HStack(spacing: 16) {
                Button(model.isPlaying ? "Dừng" : "Bắt đầu") { toggle() }
                    .buttonStyle(.borderedProminent).controlSize(.large).frame(minWidth: 160)
                Picker("Thời lượng", selection: $model.durationSeconds) {
                    Text("30s").tag(30.0); Text("1 phút").tag(60.0); Text("2 phút").tag(120.0); Text("5 phút").tag(300.0)
                }
                Picker("Chế độ", selection: $model.mode) {
                    ForEach(InputMode.allCases) { Text($0.title).tag($0) }
                }
                Toggle("FLIP", isOn: $model.flipped).toggleStyle(.button)
                Picker("Độ khó", selection: difficulty) {
                    Text("Dễ ±45ms").tag(45.0); Text("Vừa ±30ms").tag(30.0); Text("Khó ±20ms").tag(20.0)
                }
            }
            .disabled(model.isPlaying)
        }
    }

    private func circle(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title2.bold()).frame(width: 56, height: 56)
                .background(Circle().fill(Color.orange)).foregroundStyle(.white)
        }
        .buttonRepeatBehavior(.enabled)
    }

    private func toggle() {
        if model.isPlaying { model.stop(); return }
        model.play()
    }

    private var difficulty: Binding<Double> {
        Binding(get: { (model.rules.goodWindow * 1000).rounded() },
                set: { SettingsStore.scoring = ScoringRules(goodWindow: $0 / 1000); model.rules = SettingsStore.scoring })
    }

    private func tapTempo() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 3 } + [now]
        guard taps.count >= 3 else { return }
        let intervals = zip(taps, taps.dropFirst()).map { $1.timeIntervalSince($0) }
        model.settings.bpm = (60 / (intervals.reduce(0, +) / Double(intervals.count))).rounded()
    }
}
