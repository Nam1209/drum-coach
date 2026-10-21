import Testing
@testable import DrumCore

@Test func countingLabels() {
    #expect(Counting.labels(mode: .sixteenths, beats: 1).map(\.label) == ["1", "e", "&", "a"])
    #expect(Counting.labels(mode: .triplets, beats: 2).map(\.label) == ["1", "trip", "let", "2", "trip", "let"])
    #expect(Counting.labels(mode: .eighths, beats: 4).count == 8)
    #expect(Counting.labels(mode: .quarters, beats: 3).map(\.label) == ["1", "2", "3"])
}

@Test func countingPositions() {
    let l = Counting.labels(mode: .sixteenths, beats: 2)
    #expect(l[5].position == Rational(5, 4))
    #expect(Counting.labels(mode: .sixteenthTriplets, beats: 1).count == 6)
}
