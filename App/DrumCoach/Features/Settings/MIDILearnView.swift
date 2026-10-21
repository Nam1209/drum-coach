import DrumAudio
import DrumCore
import DrumLibrary
import SwiftUI

/// Hit each pad of the kit once so the app learns its MIDI notes (Roland TD-7 via a USB-MIDI cable).
struct MIDILearnView: View {
    @State private var learn = MIDILearn(map: SettingsStore.midiMap())
    @State private var waitingFor: Voice?
    @State private var source: MIDIHitSource?
    @State private var lastNote: UInt8?
    @State private var listener: Task<Void, Never>?
    private let pads: [Voice] = [.kick, .snare, .sideStick, .hiHat, .hiHatOpen, .hiHatPedal, .tom1, .tom2, .floorTom, .ride, .crash]

    var body: some View {
        Form {
            Section {
                Text("Nguồn MIDI đang kết nối: \(MIDIHitSource.sourceCount)").foregroundStyle(MIDIHitSource.sourceCount > 0 ? .green : .orange)
                if MIDIHitSource.sourceCount == 0 { Text("Cắm cáp USB-MIDI từ cổng MIDI OUT của TD-7 vào iPad.").font(.callout) }
                if let lastNote {
                    let v = DrumCore.Voice.from(midiNote: lastNote, overrides: learn.map)
                    Text("Nốt \(lastNote) → \(v?.localizedName ?? "chưa gán, sẽ bị bỏ qua khi chấm")").font(Theme.number(17, weight: .medium))
                        .foregroundStyle(v == nil ? Theme.offTime : .primary)
                }
            }
            Section("Bấm một bộ phận rồi đánh vào pad đó") {
                ForEach(pads, id: \.self) { v in
                    Button { learn.expect(v); waitingFor = v } label: {
                        HStack {
                            Text(v.displayName)
                            Spacer()
                            if waitingFor == v { Text("Đánh pad…").foregroundStyle(.orange) }
                            else if let n = learn.map.first(where: { $0.value == v })?.key { Text("nốt \(n)").foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            Button("Khôi phục mặc định (General MIDI)", role: .destructive) { learn = MIDILearn(); SettingsStore.saveMidiMap([:]) }
        }
        .navigationTitle("MIDI learn")
        .onAppear(perform: start)
        .onDisappear { listener?.cancel(); source?.stop() }
    }

    private func start() {
        let s = MIDIHitSource()
        try? s.start()
        source = s
        listener = Task { @MainActor in
            for await note in s.notes {
                lastNote = note
                if waitingFor != nil {
                    _ = learn.received(note: note)
                    waitingFor = nil
                    SettingsStore.saveMidiMap(learn.map)
                }
            }
        }
    }
}
