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
            Picker(L("Dạng bài", "Type"), selection: $kind) {
                Text("Groove Recall").tag(EarTestKind.grooveRecall)
                Text("Fill Playback").tag(EarTestKind.fillPlayback)
            }
            .pickerStyle(.segmented)
            Section {
                Text(kind == .grooveRecall
                     ? L("Nghe groove 2 ô nhịp (hi-hat, snare, kick), rồi chơi lại 4 ô nhịp. Tempo \(Int(test.bpm)) BPM.", "Listen to a 2-bar groove (hi-hat, snare, kick), then play it back for 4 bars. Tempo \(Int(test.bpm)) BPM.")
                     : L("Nghe một ô nhịp fill trên snare, chơi lại, rồi chọn đúng bản nhạc trong 2 lựa chọn. Tempo \(Int(test.bpm)) BPM.", "Listen to a 1-bar snare fill, play it back, then pick the right notation from 2 choices. Tempo \(Int(test.bpm)) BPM."))
                Button(L("▶︎ Nghe mẫu", "▶︎ Listen")) { try? player.play(test.prompt, bpm: test.bpm) }
                Button(L("Chơi lại để chấm điểm", "Play it back for a score")) { showPractice = true }
                if let playedScore { Text(L("Điểm chơi lại: \(Int(playedScore.rounded()))%", "Playback score: \(Int(playedScore.rounded()))%")) }
            }
            if kind == .fillPlayback {
                Section(L("Bản nào bạn vừa nghe?", "Which one did you hear?")) {
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
                Section(L("Kết quả", "Results")) {
                    Text("\(Int(test.score(playedScore: playedScore ?? 0, chosenIndex: chosen).rounded()))%").font(.largeTitle.bold())
                }
            }
            Button(L("Bài khác", "Another one")) { seed = UInt64.random(in: 1...1_000_000); chosen = nil; playedScore = nil }
        }
        .navigationTitle(L("Ear test, Grade \(grade)", "Ear test, Grade \(grade)"))
        .sheet(isPresented: $showPractice, onDismiss: {
            playedScore = (try? context.fetch(.init(sortBy: [SortDescriptor(\PracticeSession.date, order: .reverse)])))?.first?.score
        }) {
            NavigationStack {
                PracticeView(exercises: [kind == .grooveRecall ? repeated(test.prompt) : test.prompt],
                             voiceBank: CountVoiceBank(), bpm: test.bpm)
                    .toolbar { Button(L("Xong", "Done")) { showPractice = false } }
            }
        }
    }

    /// Groove recall is played back for four bars.
    private func repeated(_ e: Exercise) -> Exercise {
        var x = e
        let len = e.lengthInBeats
        x.notes = e.notes + e.notes.map { var n = $0; n.position = n.position + len; return n }
        x.bars = e.bars * 2
        x.title = L("Groove Recall (4 ô nhịp)", "Groove Recall (4 bars)")
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
                Section(L("Câu \(i + 1)", "Question \(i + 1)")) {
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
                Section { Text(L("Đúng \(qs.indices.filter { answers[$0] == qs[$0].answer }.count)/\(qs.count)", "Correct \(qs.indices.filter { answers[$0] == qs[$0].answer }.count)/\(qs.count)")).font(.title2.bold()) }
            }
            Button(L("Bộ câu hỏi khác", "Another set")) { seed = UInt64.random(in: 1...1_000_000); answers = [:] }
        }
        .navigationTitle(L("Câu hỏi kiến thức, Grade \(grade)", "Knowledge questions, Grade \(grade)"))
    }
}
