import Testing
@testable import DrumCore

@Test func bookTitlesAreShortened() {
    #expect(ExerciseTitle.short("Grade 3 · Nhóm A · Đánh đơn") == "Grade 3, nhóm A: Đánh đơn")
    #expect(ExerciseTitle.short("Grade 3 · Nhóm A · Đánh đơn", showingGrade: false) == "Nhóm A: Đánh đơn")
    #expect(ExerciseTitle.short("Grade 3 · Group B · Double strokes · around the toms") == "Grade 3, group B: Double strokes, around the toms")
}

@Test func otherTitlesAreLeftAlone() {
    #expect(ExerciseTitle.short("Móc đơn (single strokes)") == "Móc đơn (single strokes)")
    #expect(ExerciseTitle.short("Grade 2: Rock groove") == "Grade 2: Rock groove")
}
