import CoreMIDI
import DrumAnalysis
import DrumCore
import Foundation
import os

/// Receives note-ons from every connected MIDI source (USB-MIDI cable from the TD-7, Bluetooth MIDI…).
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
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()

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
        var status = MIDIClientCreateWithBlock("DrumCoach" as CFString, &client) { [weak self] note in
            if note.pointee.messageID == .msgSetupChanged { self?.connectAll() }
        }
        guard status == noErr else { throw MIDIError.client(status) }
        let cont = continuation, noteCont = noteContinuation
        status = MIDIInputPortCreateWithProtocol(client, "DrumCoach In" as CFString, ._1_0, &port) { [overrides, offset, pedal, hiHatByPedal] list, _ in
            for packet in list.unsafeSequence() {
                let count = Int(packet.pointee.wordCount)
                let words = withUnsafeBytes(of: packet.pointee.words) { Array($0.bindMemory(to: UInt32.self).prefix(count)) }
                let stamp = packet.pointee.timeStamp
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
        guard status == noErr else { throw MIDIError.port(status) }
        connectAll()
    }

    private func connectAll() {
        for i in 0..<MIDIGetNumberOfSources() { MIDIPortConnectSource(port, MIDIGetSource(i), nil) }
    }

    public func stop() {
        if port != 0 { MIDIPortDispose(port); port = 0 }
        if client != 0 { MIDIClientDispose(client); client = 0 }
    }

    deinit {
        stop()
        continuation.finish()
        noteContinuation.finish()
    }
}

public enum MIDIError: Error {
    case client(OSStatus), port(OSStatus)
}
