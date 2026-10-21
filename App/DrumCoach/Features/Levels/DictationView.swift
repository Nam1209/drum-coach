import DrumAnalysis
import DrumAudio
import DrumCore
import DrumLibrary
import SwiftUI

/// Rhythm dictation: hear a short snare rhythm, fill the grid with what you heard, check bar by bar.
struct DictationView: View {
    @State private var seed: UInt64 = UInt64(Date().timeIntervalSince1970)
    @State private var answer: Set<Int> = []
    @State private var checked: [Bool]?
    @State private var bpm = 70.0
    @State private var player = DrumPlayer()
    private let grid = 2
    private let bars = 2

    private var rhythm: Exercise { StickingGenerator.random(seed: seed, bars: bars, subdivision: grid, rests: true) }

    var body: some View {
        let ex = rhythm
        let perBar = Int(ex.timeSignature.beatsInQuarters.doubleValue) * grid
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Nghe chép nhịp", subtitle: "Nghe \(bars) ô nhịp nốt móc đơn, chạm vào ô có tiếng trống")
                HStack(spacing: 16) {
                    PlayButton(isPlaying: false, size: 64) {
                        try? AudioSessionConfig.activate()
                        try? player.play(ex, bpm: bpm, countInBars: 1)
                    }
                    TempoControl(bpm: $bpm, disabled: false)
                    Spacer()
                    Button("Bài khác") { seed &+= 1; answer = []; checked = nil }.buttonStyle(.bordered)
                    Button("Kiểm tra") { checked = DictationCheck.bars(answer: answer, expected: ex, grid: grid) }
                        .buttonStyle(.borderedProminent).disabled(answer.isEmpty)
                }
                Stage {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(0..<bars, id: \.self) { b in
                            HStack(spacing: 6) {
                                ForEach(0..<perBar, id: \.self) { c in cell(b * perBar + c, label: c % grid == 0 ? "\(c / grid + 1)" : "&") }
                                if let checked, b < checked.count {
                                    Image(systemName: checked[b] ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.title2).foregroundStyle(checked[b] ? Theme.onTime : Theme.missed).frame(width: 36)
                                }
                            }
                        }
                    }
                }
                if let checked, checked.contains(false) {
                    Button("Hiện đáp án") { answer = DictationCheck.cells(of: ex, grid: grid); self.checked = nil }
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.canvas)
        .onDisappear { player.stop() }
    }

    private func cell(_ i: Int, label: String) -> some View {
        let on = answer.contains(i)
        return Button {
            if on { answer.remove(i) } else { answer.insert(i) }
            checked = nil
        } label: {
            VStack(spacing: 6) {
                Circle().fill(on ? Theme.shell : Color.clear).strokeBorder(on ? Theme.shell : Theme.hairline, lineWidth: 2)
                    .frame(width: 30, height: 30)
                Text(label).font(Theme.number(14, weight: .medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ô \(label)\(on ? ", có nốt" : "")")
    }
}
