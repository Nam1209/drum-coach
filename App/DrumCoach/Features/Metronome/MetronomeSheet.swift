import DrumAudio
import DrumCore
import SwiftUI

/// "Metronome & Âm thanh": click pattern grid (5 levels per slot), presets, accent, beat skip, gap, counting voice, volumes.
struct MetronomeSheet: View {
    @Binding var settings: MetronomeSettings
    @Environment(\.dismiss) private var dismiss
    @State private var preview = TonePreview()

    private static let presets: [(String, ClickPattern)] = [
        ("Quarter", .quarter), ("8th", .eighths), ("16th", .sixteenths), ("Triplet", .triplets), ("Offbeat", .offbeat),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset") {
                    Picker("Preset", selection: presetBinding) {
                        ForEach(Self.presets.indices, id: \.self) { Text(Self.presets[$0].0).tag(Optional($0)) }
                        Text("Tùy chỉnh").tag(Int?.none)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    ClickPatternGrid(pattern: $settings.pattern, ladder: settings.ladder) { tone in
                        preview.play(tone, volume: settings.volume)
                    }
                    .padding(.vertical, 8)
                    Picker("Số ô mỗi phách", selection: slotsBinding) {
                        ForEach([1, 2, 3, 4, 6], id: \.self) { Text("\($0)").tag($0) }
                    }
                    NavigationLink("Thang âm (5 mức)") { ToneLadderEditor(ladder: $settings.ladder, volume: settings.volume) }
                } header: {
                    Text("Click Pattern")
                } footer: {
                    Text("Chạm ô: chọn mức 1–5 (chạm lại để tắt) · Nhấn giữ cột: đổi âm cho ô")
                }
                Section {
                    Toggle("Accent Beat 1", isOn: $settings.accentBeatOne)
                    Picker("Beat Skip", selection: $settings.beatSkip) {
                        Text("●●●●").tag(BeatSkip.all)
                        Text("●○●○").tag(BeatSkip.oneOnOneOff)
                        Text("●○○○").tag(BeatSkip.beatOneOnly)
                        Text("○●○●").tag(BeatSkip.backbeat)
                    }
                    Picker("Gap (tắt click theo ô nhịp)", selection: gapBinding) {
                        Text("Tắt").tag(0)
                        Text("2 chơi / 1 im").tag(1)
                        Text("2 chơi / 2 im").tag(2)
                        Text("4 chơi / 4 im").tag(3)
                    }
                    Picker("Giọng đếm", selection: $settings.voiceCount) {
                        Text("Tắt").tag(CountMode?.none)
                        Text("1 2 3 4").tag(CountMode?.some(.quarters))
                        Text("1 & 2 &").tag(CountMode?.some(.eighths))
                        Text("1 e & a").tag(CountMode?.some(.sixteenths))
                        Text("1 trip let").tag(CountMode?.some(.triplets))
                    }
                }
                Section("Âm lượng") {
                    LabeledSlider(title: "Click", value: $settings.volume)
                    LabeledSlider(title: "Giọng đếm", value: $settings.voiceVolume)
                    LabeledSlider(title: "Nhạc nền", value: $settings.musicVolume)
                }
            }
            .navigationTitle("Metronome & Âm thanh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
        }
    }

    private var presetBinding: Binding<Int?> {
        Binding(get: { Self.presets.firstIndex { $0.1 == settings.pattern } },
                set: { if let i = $0 { settings.pattern = Self.presets[i].1 } })
    }

    private var slotsBinding: Binding<Int> {
        Binding(get: { settings.pattern.slots.count }, set: { n in
            var levels = Array(repeating: 0, count: n)
            levels[0] = 4
            if n > 1, n % 2 == 0 { levels[n / 2] = 3 }
            settings.pattern = ClickPattern(levels: levels)
        })
    }

    private var gapBinding: Binding<Int> {
        let options: [GapPattern?] = [nil, GapPattern(playBars: 2, muteBars: 1), GapPattern(playBars: 2, muteBars: 2), GapPattern(playBars: 4, muteBars: 4)]
        return Binding(get: { options.firstIndex { $0 == settings.gap } ?? 0 }, set: { settings.gap = options[$0] })
    }
}

/// Columns of five stacked boxes, one column per slot of the beat.
struct ClickPatternGrid: View {
    @Binding var pattern: ClickPattern
    let ladder: [Int: LevelTone]
    let audition: (LevelTone) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(pattern.slots.indices, id: \.self) { i in
                VStack(spacing: 5) {
                    ForEach((1...5).reversed(), id: \.self) { level in
                        RoundedRectangle(cornerRadius: 7)
                            .fill(pattern.slots[i].level >= level ? Color.orange.opacity(0.3 + 0.14 * Double(level)) : Color(.systemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25)))
                            .frame(width: 56, height: 22)
                            .onTapGesture { tap(slot: i, level: level) }
                    }
                    Text(slotLabel(i)).font(.headline)
                    Text(soundName(i)).font(.caption2).foregroundStyle(.secondary)
                }
                .contextMenu {
                    Button("Âm theo mức") { pattern.slots[i].sound = nil }
                    ForEach(ClickSound.allCases, id: \.self) { s in
                        Button(Self.name(s)) { pattern.slots[i].sound = s }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tap(slot i: Int, level: Int) {
        pattern.slots[i].level = pattern.slots[i].level == level ? 0 : level
        if let tone = ToneLadder.tone(for: pattern.slots[i], ladder: ladder) { audition(tone) }
    }

    private func slotLabel(_ i: Int) -> String {
        let n = pattern.slots.count
        let names: [Int: [String]] = [1: ["1"], 2: ["1", "&"], 3: ["1", "trip", "let"], 4: ["1", "e", "&", "a"],
                                      6: ["1", "ta", "la", "&", "ta", "la"]]
        return names[n]?[i] ?? "\(i + 1)"
    }

    private func soundName(_ i: Int) -> String {
        guard let tone = ToneLadder.tone(for: pattern.slots[i], ladder: ladder) else { return "tắt" }
        return Self.name(tone.sound)
    }

    static func name(_ s: ClickSound) -> String {
        switch s {
        case .click: "click"
        case .beep: "chuông"
        case .woodblock: "woodblock"
        case .cowbell: "cowbell"
        case .hiHat: "hi-hat"
        case .rimshot: "rimshot"
        case .voice: "giọng đọc"
        }
    }
}

struct ToneLadderEditor: View {
    @Binding var ladder: [Int: LevelTone]
    let volume: Float
    @State private var preview = TonePreview()

    var body: some View {
        Form {
            ForEach((1...5).reversed(), id: \.self) { level in
                Section("Mức \(level)") {
                    Picker("Âm", selection: binding(level).sound) {
                        ForEach(ClickSound.allCases.filter { $0 != .voice }, id: \.self) { Text(ClickPatternGrid.name($0)).tag($0) }
                    }
                    Stepper("Cao độ: \(Int(binding(level).wrappedValue.pitchHz)) Hz", value: binding(level).pitchHz, in: 0...3000, step: 20)
                    Stepper("Độ to: \(Int(binding(level).wrappedValue.gainDb)) dB", value: binding(level).gainDb, in: -30...0, step: 1)
                    Button("▶︎ Nghe thử") { preview.play(binding(level).wrappedValue, volume: volume) }
                }
            }
            Button("Khôi phục mặc định", role: .destructive) { ladder = ToneLadder.default }
        }
        .navigationTitle("Thang âm")
    }

    private func binding(_ level: Int) -> Binding<LevelTone> {
        Binding(get: { ladder[level] ?? ToneLadder.default[level]! }, set: { ladder[level] = $0 })
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Float

    var body: some View {
        HStack {
            Text(title).frame(width: 100, alignment: .leading)
            Slider(value: $value, in: 0...1)
            Text("\(Int(value * 100))%").monospacedDigit().frame(width: 48, alignment: .trailing)
        }
    }
}
