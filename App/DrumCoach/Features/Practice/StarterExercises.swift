import DrumCore

/// A few app-authored exercises until the library (Task 8) exists.
enum StarterExercises {
    static let all: [Exercise] = [
        """
        title: Single Strokes (móc đơn)
        time: 4/4
        tempo: 50-90
        grid: 2
        SN: xxxxxxxx
        ST: RLRLRLRL
        """,
        """
        title: Double Strokes (móc kép)
        time: 4/4
        tempo: 50-90
        grid: 4
        SN: xxxxxxxxxxxxxxxx
        ST: RRLLRRLLRRLLRRLL
        """,
        """
        title: Single Paradiddle
        time: 4/4
        tempo: 50-90
        grid: 4
        SN: XxxxXxxxXxxxXxxx
        ST: RLRRLRLLRLRRLRLL
        """,
        """
        title: Rock Groove 8th
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
