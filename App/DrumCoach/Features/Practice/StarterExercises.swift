import DrumCore

/// A few app-authored exercises until the library (Task 8) exists.
enum StarterExercises {
    /// Computed so titles follow the current app language.
    static var all: [Exercise] {
        [
        """
        title: Móc đơn (single strokes)
        title_en: Single strokes
        time: 4/4
        tempo: 50-90
        grid: 2
        SN: xxxxxxxx
        ST: RLRLRLRL
        """,
        """
        title: Móc kép (double strokes)
        title_en: Double strokes
        time: 4/4
        tempo: 50-90
        grid: 4
        SN: xxxxxxxxxxxxxxxx
        ST: RRLLRRLLRRLLRRLL
        """,
        """
        title: Paradiddle đơn
        title_en: Single paradiddle
        time: 4/4
        tempo: 50-90
        grid: 4
        SN: XxxxXxxxXxxxXxxx
        ST: RLRRLRLLRLRRLRLL
        """,
        """
        title: Groove rock móc đơn
        title_en: Rock groove in 8ths
        time: 4/4
        tempo: 60-100
        grid: 2
        HH: xxxxxxxx
        SN: --x---x-
        BD: x---xx--
        ST: RRRRRRRR
        """,
        ].compactMap { try? ExerciseDSL.parse($0) }
    }
}
