/// Mixes triggered one-shot samples into successive output blocks.
struct ClickMixer {
    private struct Playing {
        let samples: [Float]
        let gain: Float
        var position: Int   // index into samples; negative = frames still to wait in the current block
    }

    private var playing: [Playing] = []
    var activeCount: Int { playing.count }

    /// Start `samples` at `frame` within the next rendered block.
    mutating func trigger(samples: [Float], gain: Float, atFrame frame: Int) {
        guard !samples.isEmpty else { return }
        playing.append(Playing(samples: samples, gain: gain, position: -frame))
    }

    mutating func render(into out: inout [Float]) {
        for v in playing.indices {
            var p = playing[v]
            for i in 0..<out.count {
                let s = p.position + i
                if s >= 0, s < p.samples.count { out[i] += p.samples[s] * p.gain }
            }
            p.position += out.count
            playing[v] = p
        }
        playing.removeAll { $0.position >= $0.samples.count }
        for i in out.indices { out[i] = max(-1, min(1, out[i])) }
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

    init(settings: MetronomeSettings, sampleRate: Double) {
        self.settings = settings
        self.sampleRate = sampleRate
    }

    var samplesPerBar: Double { sampleRate * settings.secondsPerBeat * Double(settings.timeSignature.beats) }

    mutating func update(_ new: MetronomeSettings, cursor: Int64) {
        let elapsed = Double(max(cursor - origin, 0))
        let barIndex = (elapsed / samplesPerBar).rounded(.down) + 1
        pending = new
        pendingAt = origin + Int64((barIndex * samplesPerBar).rounded())
    }

    mutating func events(from: Int64, to: Int64) -> [ClickEvent] {
        if let at = pendingAt, let new = pending, at < to {
            var out = at > from ? segment(from: from, to: at) : []
            settings = new
            origin = at
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
