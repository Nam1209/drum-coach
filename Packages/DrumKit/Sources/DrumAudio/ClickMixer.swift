/// Mixes triggered one-shot samples into successive output blocks.
struct ClickMixer {
    private struct Playing {
        let samples: [Float]
        let gain: Float
        var position: Int   // index into samples; negative = frames still to wait in the current block
    }

    /// Voices that can sound at once; storage is reserved up front so the audio thread never grows the array.
    static let capacity = 64
    private var playing: [Playing] = {
        var a: [Playing] = []
        a.reserveCapacity(ClickMixer.capacity)
        return a
    }()
    var activeCount: Int { playing.count }

    /// Start `samples` at `frame` within the next rendered block (dropped if every voice is busy).
    mutating func trigger(samples: [Float], gain: Float, atFrame frame: Int) {
        guard !samples.isEmpty, playing.count < Self.capacity else { return }
        playing.append(Playing(samples: samples, gain: gain, position: -frame))
    }

    mutating func render(into out: inout [Float]) { render(into: &out, count: out.count) }

    /// Mix into the first `count` frames of `out`.
    mutating func render(into out: inout [Float], count: Int) {
        for v in playing.indices {
            var p = playing[v]
            for i in 0..<count {
                let s = p.position + i
                if s >= 0, s < p.samples.count { out[i] += p.samples[s] * p.gain }
            }
            p.position += count
            playing[v] = p
        }
        playing.removeAll { $0.position >= $0.samples.count }
        for i in 0..<count { out[i] = max(-1, min(1, out[i])) }
    }
}

/// Click schedule with live settings changes that take effect on the next bar line.
struct ScheduleState {
    let sampleRate: Double
    private(set) var settings: MetronomeSettings
    /// Sample where the current settings' bar 0 begins.
    private(set) var origin: Int64 = 0
    private(set) var pending: MetronomeSettings?
    private(set) var pendingAt: Int64?
    private var pendingBeatInBar = 0
    private var labels: [String]
    private var pendingLabels: [String] = []

    init(settings: MetronomeSettings, sampleRate: Double) {
        self.settings = settings
        self.sampleRate = sampleRate
        labels = ClickSchedule.voiceLabels(for: settings)
    }

    var samplesPerBar: Double { sampleRate * settings.secondsPerBeat * Double(settings.beatsPerBar) }

    /// A new tempo (or sound) starts on the next beat and keeps that beat's place in the bar;
    /// a new meter waits for the next bar line.
    mutating func update(_ new: MetronomeSettings, cursor: Int64) {
        let elapsed = Double(max(cursor - origin, 0))
        pending = new
        pendingLabels = ClickSchedule.voiceLabels(for: new)
        if new.timeSignature != settings.timeSignature {
            let barIndex = (elapsed / samplesPerBar).rounded(.down) + 1
            pendingAt = origin + Int64((barIndex * samplesPerBar).rounded())
            pendingBeatInBar = 0
        } else {
            let samplesPerBeat = sampleRate * settings.secondsPerBeat
            let beatIndex = Int((elapsed / samplesPerBeat).rounded(.down)) + 1
            pendingAt = origin + Int64((Double(beatIndex) * samplesPerBeat).rounded())
            pendingBeatInBar = beatIndex % max(settings.beatsPerBar, 1)
        }
    }

    /// Real-time path: visit events in the window, switching to pending settings at their bar line.
    mutating func forEachEvent(from: Int64, to: Int64, _ body: (ClickEvent) -> Void) {
        if let at = pendingAt, let new = pending, at < to {
            if at > from { visit(from: from, to: at, body) }
            settings = new
            labels = pendingLabels
            // Place the new schedule so that its beat `pendingBeatInBar` falls exactly at the switch.
            origin = at - Int64((Double(pendingBeatInBar) * sampleRate * new.secondsPerBeat).rounded())
            pending = nil
            pendingAt = nil
            visit(from: max(from, at), to: to, body)
            return
        }
        visit(from: from, to: to, body)
    }

    private func visit(from: Int64, to: Int64, _ body: (ClickEvent) -> Void) {
        let o = origin
        ClickSchedule.forEachEvent(settings: settings, voiceLabels: labels, sampleRate: sampleRate, from: from - o, to: to - o) {
            body(ClickEvent(sampleTime: $0.sampleTime + o, kind: $0.kind, bar: $0.bar, level: $0.level, tone: $0.tone))
        }
    }

    mutating func events(from: Int64, to: Int64) -> [ClickEvent] {
        if let at = pendingAt, let new = pending, at < to {
            var out = at > from ? segment(from: from, to: at) : []
            settings = new
            labels = pendingLabels
            // Place the new schedule so that its beat `pendingBeatInBar` falls exactly at the switch.
            origin = at - Int64((Double(pendingBeatInBar) * sampleRate * new.secondsPerBeat).rounded())
            pending = nil
            pendingAt = nil
            out += segment(from: max(from, at), to: to)
            return out
        }
        return segment(from: from, to: to)
    }

    private func segment(from: Int64, to: Int64) -> [ClickEvent] {
        ClickSchedule.events(settings: settings, sampleRate: sampleRate, from: from - origin, to: to - origin).map {
            ClickEvent(sampleTime: $0.sampleTime + origin, kind: $0.kind, bar: $0.bar, level: $0.level, tone: $0.tone)
        }
    }
}
