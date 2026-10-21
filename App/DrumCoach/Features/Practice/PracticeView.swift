import DrumAudio
import DrumCore
import SwiftUI

struct PracticeView: View {
    @StateObject private var model: PracticeViewModel
    @State private var showSheet = false
    @State private var error: String?
    @State private var taps: [Date] = []
    private let exercises: [Exercise]

    init(exercises: [Exercise], voiceBank: CountVoiceBank) {
        self.exercises = exercises
        _model = StateObject(wrappedValue: PracticeViewModel(exercise: exercises[0], voiceBank: voiceBank))
    }

    var body: some View {
        TimelineView(.animation(paused: !model.isPlaying)) { context in
            let now = HostClock.now()
            let beat = model.beat(atHostTime: now)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    NotationView(exercise: model.playedExercise, display: model.display, beat: beat)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    RLStripView(timeline: model.displayTimeline, exercise: model.playedExercise,
                                countMode: model.settings.voiceCount ?? .eighths, beat: beat)
                    controls
                    if let error { Text(error).foregroundStyle(.red) }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showSheet) { MetronomeSheet(settings: $model.settings) }
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
            }
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
        do { try model.play(); error = nil } catch { self.error = "Không mở được âm thanh: \(error.localizedDescription)" }
    }

    private func tapTempo() {
        let now = Date()
        taps = taps.filter { now.timeIntervalSince($0) < 3 } + [now]
        guard taps.count >= 3 else { return }
        let intervals = zip(taps, taps.dropFirst()).map { $1.timeIntervalSince($0) }
        model.settings.bpm = (60 / (intervals.reduce(0, +) / Double(intervals.count))).rounded()
    }
}
