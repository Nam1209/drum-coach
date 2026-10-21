import CoreMIDI
import DrumAnalysis
import DrumCore
import Foundation
import os

/// Receives note-ons from every connected MIDI source (USB-MIDI cable from the TD-4K, Bluetooth MIDI…).
public final class MIDIHitSource: HitSource, @unchecked Sendable {
    public let hits: AsyncStream<Hit>
    public let reportDelay: TimeInterval = 0.05
    /// Raw note numbers, for MIDI learn.
    public let notes: AsyncStream<UInt8>
    private let continuation: AsyncStream<Hit>.Continuation
    private let noteContinuation: AsyncStream<UInt8>.Continuation
    private let overrides: OSAllocatedUnfairLock<[UInt8: Voice]>
    private let offset: OSAllocatedUnfairLock<TimeInterval>
    /// Last CC4 (hi-hat pedal) value, when open/closed comes from the pedal.
    private let pedal = OSAllocatedUnfairLock<Int?>(initialState: nil)
    private let hiHatByPedal: Bool
    private var token: UUID?

    public init(overrides: [UInt8: Voice] = [:], calibrationOffset: TimeInterval = 0, hiHatByPedal: Bool = false) {
        self.hiHatByPedal = hiHatByPedal
        (hits, continuation) = AsyncStream.makeStream(of: Hit.self, bufferingPolicy: .bufferingNewest(256))
        (notes, noteContinuation) = AsyncStream.makeStream(of: UInt8.self, bufferingPolicy: .bufferingNewest(64))
        self.overrides = OSAllocatedUnfairLock(initialState: overrides)
        offset = OSAllocatedUnfairLock(initialState: calibrationOffset)
    }

    public func setOverrides(_ map: [UInt8: Voice]) { overrides.withLock { $0 = map } }
    public func setCalibrationOffset(_ value: TimeInterval) { offset.withLock { $0 = value } }

    public static var sourceCount: Int { MIDIGetNumberOfSources() }

    /// A scorable hit, or nil for notes the kit mapping doesn't know: those are ignored, never counted as any drum
    /// (a voice-less hit would otherwise match like a microphone hit and inflate the score).
    static func hit(note: UInt8, velocity: UInt8, time: TimeInterval, overrides: [UInt8: Voice]) -> Hit? {
        guard let voice = Voice.from(midiNote: note, overrides: overrides) else { return nil }
        return Hit(time: time, voice: voice, velocity: Double(velocity) / 127)
    }

    public func start() throws {
        guard token == nil else { return }
        let cont = continuation, noteCont = noteContinuation
        token = try SharedMIDIInput.shared.subscribe { [overrides, offset, pedal, hiHatByPedal] words, stamp in
            let host = (stamp == 0 ? HostClock.now() : HostClock.seconds(fromHostTime: stamp)) - offset.withLock { $0 }
            let map = overrides.withLock { $0 }
            for c in MIDIParser.controllers(words: words) where c.controller == 4 { pedal.withLock { $0 = Int(c.value) } }
            for n in MIDIParser.noteOns(words: words) {
                noteCont.yield(n.note)
                guard var hit = Self.hit(note: n.note, velocity: n.velocity, time: host, overrides: map) else { continue }
                if hiHatByPedal, let v = hit.voice {
                    let voice = HiHatPedal.classify(v, pedal: pedal.withLock { $0 }, threshold: 90, higherIsClosed: true)
                    hit = Hit(time: hit.time, voice: voice, velocity: hit.velocity)
                }
                cont.yield(hit)
            }
        }
    }

    public func stop() {
        if let token { SharedMIDIInput.shared.unsubscribe(token) }
        token = nil
    }

    deinit {
        stop()
        continuation.finish()
        noteContinuation.finish()
    }
}

/// One CoreMIDI client and input port for the whole app (Apple recommends a single client):
/// created on first use and kept, so pressing Play many times does not pile up clients.
/// Each hit source subscribes while it is running.
final class SharedMIDIInput: @unchecked Sendable {
    static let shared = SharedMIDIInput()
    typealias Handler = @Sendable (_ words: [UInt32], _ timeStamp: MIDITimeStamp) -> Void

    private let handlers = OSAllocatedUnfairLock<[UUID: Handler]>(initialState: [:])
    private let ports = OSAllocatedUnfairLock<(client: MIDIClientRef, port: MIDIPortRef)?>(initialState: nil)

    func subscribe(_ handler: @escaping Handler) throws -> UUID {
        try startIfNeeded()
        let id = UUID()
        handlers.withLock { $0[id] = handler }
        return id
    }

    func unsubscribe(_ id: UUID) { handlers.withLock { _ = $0.removeValue(forKey: id) } }

    private func startIfNeeded() throws {
        try ports.withLock { state in
            guard state == nil else { return }
            var client = MIDIClientRef(), port = MIDIPortRef()
            var status = MIDIClientCreateWithBlock("DrumCoach" as CFString, &client) { [weak self] note in
                // Reconnect outside this callback: it may arrive while `ports` is still locked during setup.
                if note.pointee.messageID == .msgSetupChanged { DispatchQueue.global().async { self?.connectAll() } }
            }
            guard status == noErr else { throw MIDIError.client(status) }
            status = MIDIInputPortCreateWithProtocol(client, "DrumCoach In" as CFString, ._1_0, &port) { [handlers] list, _ in
                let current = handlers.withLock { Array($0.values) }
                guard !current.isEmpty else { return }
                for packet in list.unsafeSequence() {
                    let count = Int(packet.pointee.wordCount)
                    let words = withUnsafeBytes(of: packet.pointee.words) { Array($0.bindMemory(to: UInt32.self).prefix(count)) }
                    for h in current { h(words, packet.pointee.timeStamp) }
                }
            }
            guard status == noErr else { MIDIClientDispose(client); throw MIDIError.port(status) }
            state = (client, port)
        }
        connectAll()
    }

    /// Connects every source (new cables and Bluetooth devices too, via the setup-changed notification).
    private func connectAll() {
        guard let port = ports.withLock({ $0?.port }) else { return }
        for i in 0..<MIDIGetNumberOfSources() { MIDIPortConnectSource(port, MIDIGetSource(i), nil) }
    }
}

public enum MIDIError: Error {
    case client(OSStatus), port(OSStatus)
}
