import DrumCore

/// The 40 PAS International Drum Rudiments, written by the app in its DSL (names and stickings are common knowledge).
/// Grace notes are shown as articulations: f = flam, d = drag; rolls written as doubles, z = multiple bounce.
public enum PASRudiments {
    static let source: [(String, String, Int, String, String)] = [
        // (name, time, grid, SN line, ST line)
        ("Single Stroke Roll", "4/4", 4, "xxxxxxxxxxxxxxxx", "RLRLRLRLRLRLRLRL"),
        ("Single Stroke Four", "4/4", 4, "xxxX----xxxX----", "LRLR----RLRL----"),
        ("Single Stroke Seven", "4/4", 6, "xxxxxxX-----xxxxxxX-----", "RLRLRLR-----LRLRLRL-----"),
        ("Multiple Bounce Roll", "4/4", 2, "zzzzzzzz", "RLRLRLRL"),
        ("Triple Stroke Roll", "4/4", 6, "xxxxxxxxxxxxxxxxxxxxxxxx", "RRRLLLRRRLLLRRRLLLRRRLLL"),
        ("Double Stroke Open Roll", "4/4", 4, "xxxxxxxxxxxxxxxx", "RRLLRRLLRRLLRRLL"),
        ("Five Stroke Roll", "4/4", 4, "xxxxX---xxxxX---", "RRLLR---LLRRL---"),
        ("Six Stroke Roll", "4/4", 4, "XxxxxX--XxxxxX--", "RLLRRL--RLLRRL--"),
        ("Seven Stroke Roll", "4/4", 6, "xxxxxxX-----xxxxxxX-----", "LLRRLLR-----RRLLRRL-----"),
        ("Nine Stroke Roll", "4/4", 4, "xxxxxxxxX-------", "RRLLRRLLR-------"),
        ("Ten Stroke Roll", "4/4", 4, "xxxxxxxxXX------", "RRLLRRLLRL------"),
        ("Eleven Stroke Roll", "4/4", 4, "xxxxxxxxxxX-----", "RRLLRRLLRRL-----"),
        ("Thirteen Stroke Roll", "4/4", 4, "xxxxxxxxxxxxX---", "RRLLRRLLRRLLR---"),
        ("Fifteen Stroke Roll", "4/4", 4, "xxxxxxxxxxxxxxX-", "RRLLRRLLRRLLRRL-"),
        ("Seventeen Stroke Roll", "4/4", 4, "xxxxxxxxxxxxxxxxX---------------", "RRLLRRLLRRLLRRLLR---------------"),
        ("Single Paradiddle", "4/4", 4, "XxxxXxxxXxxxXxxx", "RLRRLRLLRLRRLRLL"),
        ("Double Paradiddle", "4/4", 3, "XxxxxxXxxxxx", "RLRLRRLRLRLL"),
        ("Triple Paradiddle", "4/4", 4, "XxxxxxxxXxxxxxxx", "RLRLRLRRLRLRLRLL"),
        ("Single Paradiddle-Diddle", "4/4", 3, "XxxxxxXxxxxx", "RLRRLLRLRRLL"),
        ("Flam", "4/4", 1, "ffff", "RLRL"),
        ("Flam Accent", "4/4", 3, "fxxfxxfxxfxx", "RLRLRLRLRLRL"),
        ("Flam Tap", "4/4", 4, "fxfxfxfxfxfxfxfx", "RRLLRRLLRRLLRRLL"),
        ("Flamacue", "4/4", 4, "fXxxf---fXxxf---", "RLRLR---LRLRL---"),
        ("Flam Paradiddle", "4/4", 4, "fxxxfxxxfxxxfxxx", "RLRRLRLLRLRRLRLL"),
        ("Single Flammed Mill", "4/4", 4, "fxxxfxxxfxxxfxxx", "RRLRLLRLRRLRLLRL"),
        ("Flam Paradiddle-Diddle", "4/4", 3, "fxxxxxfxxxxx", "RLRRLLLRLLRR"),
        ("Pataflafla", "4/4", 4, "fxxffxxffxxffxxf", "RLRLRLRLRLRLRLRL"),
        ("Swiss Army Triplet", "4/4", 3, "fxxfxxfxxfxx", "RRLRRLRRLRRL"),
        ("Inverted Flam Tap", "4/4", 4, "fxfxfxfxfxfxfxfx", "RLLRRLLRRLLRRLLR"),
        ("Flam Drag", "4/4", 3, "fdxfdxfdxfdx", "RLRLRLRLRLRL"),
        ("Drag", "4/4", 1, "dddd", "RLRL"),
        ("Single Drag Tap", "4/4", 2, "dxdxdxdx", "RLLRRLLR"),
        ("Double Drag Tap", "4/4", 3, "ddxddxddxddx", "RRLLLRRRLLLR"),
        ("Lesson 25", "4/4", 4, "dxX-dxX-dxX-dxX-", "RLR-LRL-RLR-LRL-"),
        ("Single Dragadiddle", "4/4", 4, "dxxxdxxxdxxxdxxx", "RLRRLRLLRLRRLRLL"),
        ("Drag Paradiddle #1", "2/4", 5, "XdxxxXdxxx", "RRLRRLLRLL"),
        ("Drag Paradiddle #2", "2/4", 6, "XddxxxXddxxx", "RRRLRRLLLRLL"),
        ("Single Ratamacue", "4/4", 4, "dxxXdxxXdxxXdxxX", "RLRLLRLRRLRLLRLR"),
        ("Double Ratamacue", "2/4", 6, "ddxxX-ddxxX-", "RRLRL-LLRLR-"),
        ("Triple Ratamacue", "2/4", 8, "dddxxxX-dddxxxX-", "RRRLRLR-LLLRLRL-"),
    ]

    public static let all: [Exercise] = source.enumerated().compactMap { i, r in
        try? ExerciseDSL.parse("title: \(i + 1). \(r.0)\ntime: \(r.1)\ntempo: 50-120\ngrid: \(r.2)\nSN: \(r.3)\nST: \(r.4)")
    }
}
