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
    @State private var logListener: Task<Void, Never>?
    /// Last raw messages, newest first, with the gap to the message before (to spot stray notes like note 0).
    @State private var log: [(id: Int, gapMs: Int?, message: MIDIMessage)] = []
    @State private var logCount = 0
    /// The latest stray note and the four messages before it, kept until the next stray one.
    @State private var lastStray: [(id: Int, gapMs: Int?, message: MIDIMessage)] = []
    @State private var lastMessageTime: TimeInterval?
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
            Section {
                if log.isEmpty { Text(L("Chưa có thông điệp nào. Đánh vào pad để xem.", "No messages yet. Hit a pad to see them.")).foregroundStyle(.secondary) }
                ForEach(log, id: \.id) { row in
                    HStack {
                        Text(row.message.summary).font(Theme.number(15, weight: .medium))
                            .foregroundStyle(isStray(row.message) ? Theme.offTime : .primary)
                        Spacer()
                        Text(row.gapMs.map { "+\($0) ms" } ?? "").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(L("10 thông điệp MIDI gần nhất", "Last 10 MIDI messages"))
            } footer: {
                Text(L("Màu cam là nốt không thuộc trống nào (ví dụ nốt 0). Nếu \"lực\" của nốt đó bằng đúng số nốt của pad vừa đánh (vd. vel 38), cáp USB-MIDI đang làm rơi dữ liệu.", "Orange marks a note no drum uses (e.g. note 0). If its velocity equals the pad's note number (e.g. vel 38), the USB-MIDI cable is dropping data."))
            }
            if !lastStray.isEmpty {
                Section(L("Nốt lạ gần nhất và 4 thông điệp ngay trước", "Latest stray note and the 4 messages before it")) {
                    ForEach(lastStray, id: \.id) { row in
                        HStack {
                            Text(row.message.summary).font(Theme.number(15, weight: .medium))
                                .foregroundStyle(isStray(row.message) ? Theme.offTime : .primary)
                            Spacer()
                            Text(row.gapMs.map { "+\($0) ms" } ?? "").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Button(L("Khôi phục mặc định (General MIDI)", "Restore defaults (General MIDI)"), role: .destructive) { learn = MIDILearn(); SettingsStore.saveMidiMap([:]) }
        }
        .navigationTitle("MIDI learn")
        .onAppear(perform: start)
        .onDisappear { listener?.cancel(); logListener?.cancel(); source?.stop() }
    }

    private func start() {
        let s = MIDIHitSource()
        try? s.start()
        source = s
        logListener = Task { @MainActor in
            for await (time, message) in s.messages {
                let gap = lastMessageTime.map { Int(((time - $0) * 1000).rounded()) }
                lastMessageTime = time
                logCount += 1
                log = Array(([(id: logCount, gapMs: gap, message: message)] + log).prefix(10))
                if isStray(message) { lastStray = Array(log.prefix(5)) }
            }
        }
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

    /// A note-on that no drum (default or learned) uses.
    private func isStray(_ m: MIDIMessage) -> Bool {
        m.status & 0xF0 == 0x90 && m.data2 > 0 && DrumCore.Voice.from(midiNote: m.data1, overrides: learn.map) == nil
    }
}
