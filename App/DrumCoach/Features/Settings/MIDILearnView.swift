import DrumAudio
import DrumCore
import DrumLibrary
import SwiftUI

/// Hit each pad of the kit once so the app learns its MIDI notes (Roland TD-4K via a USB-MIDI cable).
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
                Text(L("Nguồn MIDI đang kết nối: \(MIDIHitSource.sourceCount)", "Connected MIDI sources: \(MIDIHitSource.sourceCount)")).foregroundStyle(MIDIHitSource.sourceCount > 0 ? .green : .orange)
                if MIDIHitSource.sourceCount == 0 { Text(L("Cắm cáp USB-MIDI từ cổng MIDI OUT của TD-4K vào iPad, hoặc ghép nối bộ chuyển MIDI Bluetooth.", "Connect a USB-MIDI cable from the TD-4K MIDI OUT port to the iPad, or pair a Bluetooth MIDI adapter.")).font(.callout) }
                BluetoothMIDIButton()
                if let lastNote {
                    let v = DrumCore.Voice.from(midiNote: lastNote, overrides: learn.map)
                    Text(L("Nốt \(lastNote) → \(v?.localizedName ?? "chưa gán, sẽ bị bỏ qua khi chấm")", "Note \(lastNote) → \(v?.localizedName ?? "not mapped, ignored when scoring")")).font(Theme.number(17, weight: .medium))
                        .foregroundStyle(v == nil ? Theme.offTime : .primary)
                }
            }
            Section(L("Bấm một bộ phận rồi đánh vào pad đó", "Tap a drum, then hit that pad")) {
                ForEach(pads, id: \.self) { v in
                    Button { learn.expect(v); waitingFor = v } label: {
                        HStack {
                            Text(v.displayName)
                            Spacer()
                            if waitingFor == v { Text(L("Đánh pad…", "Hit the pad…")).foregroundStyle(.orange) }
                            else if let n = learn.map.first(where: { $0.value == v })?.key { Text(L("nốt \(n)", "note \(n)")).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            Button(L("Khôi phục mặc định (General MIDI)", "Restore defaults (General MIDI)"), role: .destructive) { learn = MIDILearn(); SettingsStore.saveMidiMap([:]) }
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
