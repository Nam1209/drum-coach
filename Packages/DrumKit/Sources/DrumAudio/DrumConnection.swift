import CoreMIDI
import DrumCore
import Foundation

/// Whether the e-kit is reachable. A 5-pin MIDI cable cannot tell whether the drum module at the other end is on,
/// so "the kit works" is only certain once a note has arrived recently.
public enum DrumConnection {
    public enum State: Equatable, Sendable {
        case notConnected
        case cableOnly(name: String)
        case receiving(name: String)
    }

    /// Seconds a hit keeps the state at `.receiving`.
    public static let recentHit: TimeInterval = 5

    public static func state(sources: [String], lastHit: Date?, now: Date) -> State {
        guard !sources.isEmpty else { return .notConnected }
        let name = sources.joined(separator: ", ")
        if let lastHit, now.timeIntervalSince(lastHit) <= recentHit { return .receiving(name: name) }
        return .cableOnly(name: name)
    }

    /// Display names of the connected MIDI sources (cables, Bluetooth MIDI…).
    public static func sourceNames() -> [String] {
        (0..<MIDIGetNumberOfSources()).map { i in
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(MIDIGetSource(i), kMIDIPropertyDisplayName, &name)
            return name?.takeRetainedValue() as String? ?? "MIDI \(i + 1)"
        }
    }
}

/// Watches the kit for the whole app: connected sources and the last note heard.
@MainActor
public final class DrumConnectionMonitor: ObservableObject {
    public static let shared = DrumConnectionMonitor()

    @Published public private(set) var state: DrumConnection.State = .notConnected
    @Published public private(set) var lastNote: UInt8?
    private var lastHit: Date?
    private var source: MIDIHitSource?
    private var tasks: [Task<Void, Never>] = []

    public func start() {
        guard source == nil else { return }
        let s = MIDIHitSource()
        try? s.start()
        source = s
        tasks.append(Task { [weak self] in
            for await note in s.notes {
                self?.lastNote = note
                self?.lastHit = Date()
                self?.refresh()
            }
        })
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        })
    }

    private func refresh() {
        let new = DrumConnection.state(sources: DrumConnection.sourceNames(), lastHit: lastHit, now: Date())
        if new != state { state = new }
    }
}
