import Foundation
import Testing
@testable import DrumAudio

private let now = Date(timeIntervalSince1970: 1_000)

@Test func noCableMeansNotConnected() {
    #expect(DrumConnection.state(sources: [], lastHit: nil, now: now) == .notConnected)
    #expect(DrumConnection.state(sources: [], lastHit: now, now: now) == .notConnected)   // a stale hit after unplugging
}

@Test func cableWithoutRecentHitsIsWaiting() {
    #expect(DrumConnection.state(sources: ["UM-ONE"], lastHit: nil, now: now) == .cableOnly(name: "UM-ONE"))
    #expect(DrumConnection.state(sources: ["UM-ONE"], lastHit: now.addingTimeInterval(-10), now: now) == .cableOnly(name: "UM-ONE"))
}

@Test func recentHitMeansTheKitIsTalking() {
    #expect(DrumConnection.state(sources: ["UM-ONE"], lastHit: now.addingTimeInterval(-2), now: now) == .receiving(name: "UM-ONE"))
    #expect(DrumConnection.state(sources: ["UM-ONE", "Bluetooth"], lastHit: now, now: now) == .receiving(name: "UM-ONE, Bluetooth"))
}
