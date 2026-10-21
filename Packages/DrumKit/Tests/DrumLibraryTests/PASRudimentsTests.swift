import DrumCore
import Testing
@testable import DrumLibrary

@Test func fortyRudimentsParseWithSticking() throws {
    #expect(PASRudiments.all.count == 40)
    #expect(Set(PASRudiments.all.map(\.title)).count == 40)
    for r in PASRudiments.all {
        #expect(!r.notes.isEmpty, "\(r.title)")
        #expect(r.notes.allSatisfy { $0.hand != nil }, "\(r.title) needs sticking on every note")
    }
    #expect(PASRudiments.all[0].title.hasPrefix("1."))
    #expect(PASRudiments.all[39].title.contains("Triple Ratamacue"))
}
