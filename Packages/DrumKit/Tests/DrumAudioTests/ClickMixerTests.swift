import Testing
import DrumCore
@testable import DrumAudio

private func impulse(_ n: Int) -> [Float] { [Float](repeating: 1, count: n) }

@Test func mixerPlacesEventAtFrameOffset() {
    var m = ClickMixer()
    var out = [Float](repeating: 0, count: 64)
    m.trigger(samples: impulse(4), gain: 0.5, atFrame: 10)
    m.render(into: &out)
    #expect(out[9] == 0)
    #expect(out[10...13].allSatisfy { $0 == 0.5 })
    #expect(out[14] == 0)
}

@Test func mixerCarriesVoiceAcrossBlocks() {
    var m = ClickMixer()
    var a = [Float](repeating: 0, count: 8), b = [Float](repeating: 0, count: 8)
    m.trigger(samples: impulse(6), gain: 1, atFrame: 5)
    m.render(into: &a)
    m.render(into: &b)
    #expect(a[5...7].allSatisfy { $0 == 1 })
    #expect(b[0...2].allSatisfy { $0 == 1 })
    #expect(b[3] == 0)
    #expect(m.activeCount == 0)
}

@Test func mixerSumsOverlappingVoicesAndClips() {
    var m = ClickMixer()
    var out = [Float](repeating: 0, count: 4)
    m.trigger(samples: impulse(4), gain: 0.8, atFrame: 0)
    m.trigger(samples: impulse(4), gain: 0.8, atFrame: 0)
    m.render(into: &out)
    #expect(out.allSatisfy { $0 == 1 })   // 1.6 clipped to 1
}

@Test func scheduleStateAppliesTempoChangeAtNextBar() {
    // 4/4 at 60 bpm, 48 kHz: one bar = 192 000 samples.
    var st = ScheduleState(settings: MetronomeSettings(bpm: 60), sampleRate: 48_000)
    st.update(MetronomeSettings(bpm: 120), cursor: 50_000)
    #expect(st.pendingAt == 192_000)
    let before = st.events(from: 140_000, to: 192_000)
    #expect(before.map(\.sampleTime) == [192_000 - 48_000])            // still 60 bpm
    let after = st.events(from: 192_000, to: 192_000 + 48_000)
    #expect(after.map(\.sampleTime) == [192_000, 192_000 + 24_000])    // 120 bpm from the bar line
    #expect(after.first?.kind == .downbeat)
    #expect(st.origin == 192_000)
}

@Test func scheduleStateSplitsBlockAcrossChange() {
    var st = ScheduleState(settings: MetronomeSettings(bpm: 60), sampleRate: 48_000)
    st.update(MetronomeSettings(bpm: 120), cursor: 0)
    let e = st.events(from: 180_000, to: 200_000)
    #expect(e.map(\.sampleTime) == [192_000])
}

@Test func forEachEventMatchesEventsWithoutSorting() {
    var st = ScheduleState(settings: MetronomeSettings(bpm: 97, pattern: .sixteenths, voiceCount: .sixteenths), sampleRate: 48_000)
    var st2 = st
    var visited: [ClickEvent] = []
    var t: Int64 = 0
    while t < 300_000 { st.forEachEvent(from: t, to: t + 512) { visited.append($0) }; t += 512 }
    let expected = st2.events(from: 0, to: 300_000)
    #expect(Set(visited) == Set(expected))
    #expect(visited.count == expected.count)
}

@Test func mixerHasFixedCapacity() {
    var m = ClickMixer()
    for _ in 0..<500 { m.trigger(samples: [1, 1, 1], gain: 1, atFrame: 0) }
    #expect(m.activeCount <= ClickMixer.capacity)
}
