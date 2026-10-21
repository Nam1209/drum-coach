import Foundation

public enum DSLError: Error, Equatable, Sendable {
    case missingHeader(String)
    case unequalLineLengths
    case unknownVoice(String)
    case badSymbol(Character, line: Int)
    case lengthNotMultipleOfBar
}

/// Text grid format for exercises. Each character is one grid cell; `grid` is cells per notated beat
/// (per quarter in x/4, per eighth in x/8). `|` and spaces are ignored.
///
///     title: Single Paradiddle
///     time: 4/4
///     tempo: 60-120
///     grid: 4
///     SN: x-x-X-g-...
///     ST: RLRRLRLL...
public enum ExerciseDSL {
    static let voiceCodes: [String: Voice] = [
        "HH": .hiHat, "OH": .hiHatOpen, "HP": .hiHatPedal, "SN": .snare, "SS": .sideStick, "BD": .kick,
        "T1": .tom1, "T2": .tom2, "FT": .floorTom, "RD": .ride, "CR": .crash,
    ]
    static let codeOrder = ["CR", "RD", "HH", "OH", "T1", "T2", "SN", "SS", "FT", "BD", "HP"]

    public static func parse(_ text: String) throws(DSLError) -> Exercise {
        var headers: [String: String] = [:]
        var rows: [(lineNo: Int, code: String, cells: [Character])] = []
        var sticking: [Character]?

        for (i, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            let lower = key.lowercased()
            if ["title", "time", "tempo", "grid"].contains(lower) {
                headers[lower] = value
            } else if key == "ST" {
                sticking = value.filter { $0 != "|" && $0 != " " }.map { $0 }
            } else {
                guard voiceCodes[key] != nil else { throw .unknownVoice(key) }
                rows.append((i + 1, key, value.filter { $0 != "|" && $0 != " " }.map { $0 }))
            }
        }

        guard let timeText = headers["time"] else { throw .missingHeader("time") }
        // Bounded so text from Notion/Claude can never overflow the arithmetic below.
        guard let gridText = headers["grid"], let grid = Int(gridText), (1...48).contains(grid) else { throw .missingHeader("grid") }
        let parts = timeText.split(separator: "/").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, (1...32).contains(parts[0]), [1, 2, 4, 8, 16, 32].contains(parts[1]) else { throw .missingHeader("time") }
        guard rows.allSatisfy({ $0.cells.count <= 20_000 }) else { throw .lengthNotMultipleOfBar }
        let ts = TimeSignature(beats: parts[0], unit: parts[1])

        let length = rows.first?.cells.count ?? sticking?.count ?? 0
        if rows.contains(where: { $0.cells.count != length }) || (sticking.map { $0.count != length } ?? false) {
            throw .unequalLineLengths
        }
        let cellsPerBar = grid * ts.beats
        guard length > 0, length % cellsPerBar == 0 else { throw .lengthNotMultipleOfBar }

        // One cell = 1/grid of a notated beat = (4/unit)/grid quarters.
        let cellLength = Rational(4, ts.unit * grid)
        var notes: [NoteEvent] = []
        for row in rows {
            let voice = voiceCodes[row.code]!
            for (idx, ch) in row.cells.enumerated() {
                let articulation: Articulation
                switch ch {
                case "-": continue
                case "x", "o": articulation = .normal
                case "X", "O": articulation = .accent
                case "g": articulation = .ghost
                case "f": articulation = .flam
                case "d": articulation = .drag
                case "z": articulation = .buzz
                default: throw .badSymbol(ch, line: row.lineNo)
                }
                notes.append(NoteEvent(position: cellLength * Rational(idx, 1), voice: voice,
                                       hand: hand(for: voice, sticking: sticking?[idx]), articulation: articulation))
            }
        }
        notes.sort { $0.position == $1.position ? $0.voice.staffStep > $1.voice.staffStep : $0.position < $1.position }

        return Exercise(id: Exercise.stableID(for: text), title: headers["title"] ?? "Untitled", source: "User", timeSignature: ts,
                        bars: length / cellsPerBar, suggestedTempo: parseTempo(headers["tempo"]), notes: notes)
    }

    public static func serialize(_ exercise: Exercise, grid: Int) -> String {
        let ts = exercise.timeSignature
        let cellLength = Rational(4, ts.unit * grid)
        let count = grid * ts.beats * exercise.bars
        func cellIndex(_ p: Rational) -> Int { Int(((p.doubleValue / cellLength.doubleValue)).rounded()) }

        var lines = ["title: \(exercise.title)", "time: \(ts.beats)/\(ts.unit)",
                     "tempo: \(exercise.suggestedTempo.lowerBound)-\(exercise.suggestedTempo.upperBound)", "grid: \(grid)"]
        for code in codeOrder {
            let voice = voiceCodes[code]!
            let voiceNotes = exercise.notes.filter { $0.voice == voice }
            guard !voiceNotes.isEmpty else { continue }
            var cells = Array(repeating: Character("-"), count: count)
            for n in voiceNotes { cells[cellIndex(n.position)] = symbol(for: n.articulation) }
            lines.append("\(code): \(String(cells))")
        }
        var st = Array(repeating: Character("-"), count: count)
        for n in exercise.notes {
            guard let h = n.hand else { continue }
            let i = cellIndex(n.position)
            if h == .foot { if st[i] == "-" { st[i] = "F" } } else { st[i] = Character(h.rawValue) }
        }
        if st.contains(where: { $0 != "-" }) { lines.append("ST: \(String(st))") }
        return lines.joined(separator: "\n")
    }

    private static func hand(for voice: Voice, sticking: Character?) -> Hand? {
        let isFoot = voice == .kick || voice == .hiHatPedal
        switch sticking {
        case "R": return isFoot ? nil : .right
        case "L": return isFoot ? nil : .left
        case "F": return isFoot ? .foot : nil
        default: return nil
        }
    }

    private static func symbol(for a: Articulation) -> Character {
        switch a {
        case .normal: "x"
        case .accent: "X"
        case .ghost: "g"
        case .flam: "f"
        case .drag: "d"
        case .buzz: "z"
        }
    }

    private static func parseTempo(_ text: String?) -> ClosedRange<Int> {
        guard let text else { return 60...120 }
        let parts = text.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count == 2, parts[0] <= parts[1] { return parts[0]...parts[1] }
        if parts.count == 1 { return parts[0]...parts[0] }
        return 60...120
    }
}
