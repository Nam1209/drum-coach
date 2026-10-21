import DrumAnalysis
import DrumAudio
import DrumCore
import DrumLibrary
import SwiftUI

/// Rockschool-style ear tests: listen to the example (twice), then play it back with scoring.
struct EarTestView: View {
    let grade: Int
    @State private var kind: EarTestKind = .grooveRecall
    @State private var seed: UInt64 = UInt64.random(in: 1...1_000_000)
    @State private var player = DrumPlayer()
    @State private var chosen: Int?
    @State private var playedScore: Double?
    @State private var showPractice = false
    @Environment(\.modelContext) private var context

    var body: some View {
        let test = EarTest(kind: kind, grade: grade, seed: seed)
        Form {
            Picker("Dạng bài", selection: $kind) {
                Text("Groove Recall").tag(EarTestKind.grooveRecall)
                Text("Fill Playback").tag(EarTestKind.fillPlayback)
            }
            .pickerStyle(.segmented)
            Section {
                Text(kind == .grooveRecall
                     ? "Nghe groove 2 ô nhịp (hi-hat, snare, kick), rồi chơi lại 4 ô nhịp. ♩ = \(Int(test.bpm))"
                     : "Nghe một ô nhịp fill trên snare, chơi lại, rồi chọn đúng bản nhạc trong 2 lựa chọn. ♩ = \(Int(test.bpm))")
                Button("▶︎ Nghe mẫu") { try? player.play(test.prompt, bpm: test.bpm) }
                Button("Chơi lại để chấm điểm") { showPractice = true }
                if let playedScore { Text("Điểm chơi lại: \(Int(playedScore.rounded()))%") }
            }
            if kind == .fillPlayback {
                Section("Bản nào bạn vừa nghe?") {
                    ForEach(Array(test.choices.enumerated()), id: \.offset) { i, ex in
                        Button { chosen = i } label: {
                            HStack {
                                Text(i == 0 ? "A" : "B").font(.headline)
                                NotationView(exercise: ex, display: .page, beat: nil).frame(height: 150)
                                if chosen == i { Image(systemName: i == test.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(i == test.correctIndex ? .green : .red) }
                            }
                        }
                    }
                }
            }
            if playedScore != nil || chosen != nil {
                Section("Kết quả") {
                    Text("\(Int(test.score(playedScore: playedScore ?? 0, chosenIndex: chosen).rounded()))%").font(.largeTitle.bold())
                }
            }
            Button("Bài khác") { seed = UInt64.random(in: 1...1_000_000); chosen = nil; playedScore = nil }
        }
        .navigationTitle("Ear Test · Grade \(grade)")
        .sheet(isPresented: $showPractice, onDismiss: {
            playedScore = (try? context.fetch(.init(sortBy: [SortDescriptor(\PracticeSession.date, order: .reverse)])))?.first?.score
        }) {
            NavigationStack {
                PracticeView(exercises: [kind == .grooveRecall ? repeated(test.prompt) : test.prompt],
                             voiceBank: CountVoiceBank(), bpm: test.bpm)
                    .toolbar { Button("Xong") { showPractice = false } }
            }
        }
    }

    /// Groove recall is played back for four bars.
    private func repeated(_ e: Exercise) -> Exercise {
        var x = e
        let len = e.lengthInBeats
        x.notes = e.notes + e.notes.map { var n = $0; n.position = n.position + len; return n }
        x.bars = e.bars * 2
        x.title = "Groove Recall (4 ô nhịp)"
        return x
    }
}

struct GMQuizView: View {
    let grade: Int
    @State private var seed: UInt64 = UInt64.random(in: 1...1_000_000)
    @State private var answers: [Int: Int] = [:]

    var body: some View {
        let qs = GMQuiz.questions(grade: grade, seed: seed)
        Form {
            ForEach(Array(qs.enumerated()), id: \.offset) { i, q in
                Section("Câu \(i + 1)") {
                    Text(q.text).bold()
                    ForEach(Array(q.options.enumerated()), id: \.offset) { j, opt in
                        Button { answers[i] = j } label: {
                            HStack {
                                Text(opt)
                                Spacer()
                                if answers[i] == j { Image(systemName: j == q.answer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(j == q.answer ? .green : .red) }
                            }
                        }
                    }
                }
            }
            if answers.count == qs.count {
                Section { Text("Đúng \(qs.indices.filter { answers[$0] == qs[$0].answer }.count)/\(qs.count)").font(.title2.bold()) }
            }
            Button("Bộ câu hỏi khác") { seed = UInt64.random(in: 1...1_000_000); answers = [:] }
        }
        .navigationTitle("GMQ · Grade \(grade)")
    }
}
