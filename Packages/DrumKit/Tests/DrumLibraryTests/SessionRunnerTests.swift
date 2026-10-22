import Testing
@testable import DrumLibrary

@Test func runnerAdvancesAtBoundaries() {
    var r = SessionRunner(segments: [.init(title: "Khởi động", minutes: 5), .init(title: "Bài chính", minutes: 10), .init(title: "Bài vui", minutes: 10)])
    #expect(r.current?.title == "Khởi động")
    #expect(r.tick(299) == false)
    #expect(r.tick(1) == true)
    #expect(r.current?.title == "Bài chính")
    #expect(r.remaining == 600)
    #expect(r.tick(600) == true)
    #expect(r.current?.title == "Bài vui")
    #expect(abs(r.completedMinutes - 15) < 1e-9)
}

@Test func skipMovesOnAndCountsOnlyPlayedTime() {
    var r = SessionRunner(segments: [.init(title: "A", minutes: 5), .init(title: "B", minutes: 5)])
    _ = r.tick(60)
    r.skip()
    #expect(r.current?.title == "B")
    #expect(abs(r.completedMinutes - 1) < 1e-9)
    r.skip()
    #expect(r.current == nil)
    #expect(r.isFinished)
}

@Test func largeTickCrossesSeveralSegments() {
    var r = SessionRunner(segments: [.init(title: "A", minutes: 1), .init(title: "B", minutes: 1), .init(title: "C", minutes: 1)])
    #expect(r.tick(150) == true)
    #expect(r.current?.title == "C")
    #expect(r.remaining == 30)
}
