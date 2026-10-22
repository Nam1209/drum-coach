import DrumAudio
import DrumCore
import SwiftUI

/// The e-kit connection at a glance; tapping it opens MIDI learn to see each note as it arrives.
struct DrumStatusPill: View {
    @ObservedObject private var monitor = DrumConnectionMonitor.shared
    /// Inside a card row: no capsule of its own, full width.
    var inCard = false

    var body: some View {
        NavigationLink { MIDILearnView() } label: {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                }
                if inCard { Spacer() }
                Image(systemName: "chevron.forward").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, inCard ? 0 : 14).padding(.vertical, inCard ? 0 : 9)
            .background(Capsule().fill(inCard ? Color.clear : Theme.stage))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch monitor.state {
        case .notConnected: .gray
        case .cableOnly: Theme.shell
        case .receiving: Theme.onTime
        }
    }

    private var title: String {
        switch monitor.state {
        case .notConnected: L("Chưa kết nối trống", "Kit not connected")
        case .cableOnly(let name): L("Đã thấy \(name)", "Found \(name)")
        case .receiving: L("Trống đang gửi nốt", "Kit is sending notes")
        }
    }

    private var detail: String {
        switch monitor.state {
        case .notConnected: L("Ghép MIDI Bluetooth trong Cài đặt, hoặc cắm cáp USB-MIDI", "Pair Bluetooth MIDI in Settings, or plug in a USB-MIDI cable")
        case .cableOnly: L("Bật trống rồi đánh thử một pad", "Turn the kit on and hit a pad")
        case .receiving:
            monitor.lastNote.map { n in
                let name = Voice.from(midiNote: n, overrides: SettingsStore.midiMap())?.localizedName ?? L("chưa gán", "not mapped")
                return L("Nốt \(n) → \(name)", "Note \(n) → \(name)")
            } ?? ""
        }
    }
}
