import DrumCore
import Testing
@testable import DrumLibrary

@Test func everyCurriculumExerciseParses() throws {
    #expect(Grade8Curriculum.units.count >= 8)
    for unit in Grade8Curriculum.units {
        #expect(unit.exercises.count >= 3, "\(unit.id) needs at least 3 exercises")
        for dsl in unit.exercises {
            let ex = try ExerciseDSL.parse(dsl)
            #expect(ex.suggestedTempo.lowerBound >= 30)
            #expect(ex.suggestedTempo.lowerBound <= ex.suggestedTempo.upperBound)
        }
    }
}

@Test func unitIdsAreUnique() {
    #expect(Set(Grade8Curriculum.units.map(\.id)).count == Grade8Curriculum.units.count)
}
