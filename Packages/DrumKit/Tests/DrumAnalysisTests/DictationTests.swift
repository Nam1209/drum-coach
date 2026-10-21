import DrumCore
import Testing
@testable import DrumAnalysis

@Test func dictationMarksEachBar() throws {
    let ex = try ExerciseDSL.parse("time: 4/4\ngrid: 2\nSN: x-x-x-x-|xx--x-x-")
    // answer: cell indices (8ths) the student filled in
    let right: Set<Int> = [0, 2, 4, 6, 8, 9, 12, 14]
    #expect(DictationCheck.bars(answer: right, expected: ex, grid: 2) == [true, true])
    #expect(DictationCheck.bars(answer: [0, 2, 4, 6, 8, 12, 14], expected: ex, grid: 2) == [true, false])
    #expect(DictationCheck.cells(of: ex, grid: 2) == right)
}

@Test func hiHatPedalDecidesOpenOrClosed() {
    #expect(HiHatPedal.classify(.hiHat, pedal: 120, threshold: 90, higherIsClosed: true) == .hiHat)
    #expect(HiHatPedal.classify(.hiHat, pedal: 0, threshold: 90, higherIsClosed: true) == .hiHatOpen)
    #expect(HiHatPedal.classify(.hiHatOpen, pedal: 127, threshold: 90, higherIsClosed: true) == .hiHat)
    #expect(HiHatPedal.classify(.snare, pedal: 0, threshold: 90, higherIsClosed: true) == .snare)
    #expect(HiHatPedal.classify(.hiHat, pedal: nil, threshold: 90, higherIsClosed: true) == .hiHat)
}
