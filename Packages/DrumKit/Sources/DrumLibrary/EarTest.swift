import DrumCore

public enum EarTestKind: String, Codable, Sendable { case fillPlayback, grooveRecall }

/// Rockschool-style ear tests: hear a one-bar snare fill and play it back (then pick it from two), or hear a two-bar
/// groove and play it back.
public struct EarTest: Sendable {
    public let kind: EarTestKind
    public let prompt: Exercise
    /// fillPlayback: two candidates, one equal to `prompt`.
    public let choices: [Exercise]
    public let correctIndex: Int
    public let bpm: Double

    public init(kind: EarTestKind, grade: Int, seed: UInt64) {
        var rng = LibraryRNG(seed: seed &* 31 &+ UInt64(grade))
        self.kind = kind
        let sixteenths = grade >= 2
        switch kind {
        case .fillPlayback:
            bpm = grade <= 2 ? 70 : 75
            let a = Self.fill(&rng, sixteenths: sixteenths, title: "Fill A")
            var b = Self.fill(&rng, sixteenths: sixteenths, title: "Fill B")
            while b.notes == a.notes { b = Self.fill(&rng, sixteenths: sixteenths, title: "Fill B") }
            let first = rng.nextUnit() < 0.5
            prompt = a
            choices = first ? [a, b] : [b, a]
            correctIndex = first ? 0 : 1
        case .grooveRecall:
            bpm = grade <= 2 ? 80 : 90
            prompt = Self.groove(&rng, sixteenths: sixteenths)
            choices = []
            correctIndex = 0
        }
    }

    /// Fill playback: 70% playing accuracy + 30% for recognising the fill. Groove recall: playing accuracy.
    public func score(playedScore: Double, chosenIndex: Int?) -> Double {
        switch kind {
        case .grooveRecall: return playedScore
        case .fillPlayback: return 0.7 * playedScore + (chosenIndex == correctIndex ? 30 : 0)
        }
    }

    private static func fill(_ rng: inout LibraryRNG, sixteenths: Bool, title: String) -> Exercise {
        let options: [String] = sixteenths ? ["x-x-", "xxxx", "x---", "xx-x", "x-xx"] : ["x-x-", "x---", "x-x-"]
        var cells = ""
        for beat in 0..<4 { cells += beat == 3 ? "x---" : options[Int(rng.nextUnit() * Double(options.count)) % options.count] }
        return (try? ExerciseDSL.parse("title: \(title)\ntime: 4/4\ntempo: 70-70\ngrid: 4\nSN: \(cells)"))
            ?? Exercise(title: title, source: "Ear test", timeSignature: TimeSignature(beats: 4, unit: 4), bars: 1, suggestedTempo: 70...70, notes: [])
    }

    private static func groove(_ rng: inout LibraryRNG, sixteenths: Bool) -> Exercise {
        let kicks = ["x-------x-------", "x-------x-x-----", "x-----x-x-------", "x--x----x-------"]
        var bd = "", hh = "", sn = ""
        for _ in 0..<2 {
            bd += kicks[Int(rng.nextUnit() * Double(kicks.count)) % kicks.count]
            hh += "x-x-x-x-x-x-x-x-"
            sn += sixteenths && rng.nextUnit() < 0.5 ? "----x-------x--x" : "----x-------x---"
        }
        return (try? ExerciseDSL.parse("title: Groove\ntime: 4/4\ntempo: 80-80\ngrid: 4\nHH: \(hh)\nSN: \(sn)\nBD: \(bd)"))
            ?? Exercise(title: "Groove", source: "Ear test", timeSignature: TimeSignature(beats: 4, unit: 4), bars: 2, suggestedTempo: 80...80, notes: [])
    }
}

public struct GMQuestion: Codable, Sendable, Equatable {
    public let text: String
    public let options: [String]
    public let answer: Int
    public let grade: Int
}

/// General Musicianship Questions practice (Rockschool asks five: four on music knowledge, one on the instrument).
public enum GMQuiz {
    /// Recomputed on access so questions follow the current app language.
    static var pool: [GMQuestion] { [
        GMQuestion(text: L("Trên khuông nhạc trống, kick (trống bass) nằm ở đâu?", "On a drum staff, where is the kick (bass drum)?"), options: [L("Khe dưới cùng", "Bottom space"), L("Khe thứ 3", "Third space"), L("Trên khuông", "Above the staff")], answer: 0, grade: 1),
        GMQuestion(text: L("Snare nằm ở vị trí nào?", "Where is the snare written?"), options: [L("Khe thứ 3 từ dưới lên", "Third space from the bottom"), L("Dòng trên cùng", "Top line"), L("Dưới khuông", "Below the staff")], answer: 0, grade: 1),
        GMQuestion(text: L("Nốt hình chữ x trên khuông thường là gì?", "What is an x-shaped notehead usually?"), options: [L("Chũm chọe (hi-hat, ride, crash)", "A cymbal (hi-hat, ride, crash)"), L("Tom", "A tom"), L("Kick", "The kick")], answer: 0, grade: 1),
        GMQuestion(text: L("Số chỉ nhịp 4/4 nghĩa là?", "What does a 4/4 time signature mean?"), options: [L("4 phách nốt đen mỗi ô nhịp", "4 quarter-note beats per bar"), L("4 nốt móc đơn mỗi ô nhịp", "4 eighth notes per bar"), "Tempo 44"], answer: 0, grade: 1),
        GMQuestion(text: L("Một nốt đen bằng bao nhiêu nốt móc đơn?", "How many eighth notes make a quarter note?"), options: ["2", "4", "3"], answer: 0, grade: 1),
        GMQuestion(text: L("Dấu lặng là gì?", "What is a rest?"), options: [L("Ký hiệu không đánh trong một khoảng thời gian", "A sign for silence lasting a set time"), L("Nốt đánh mạnh", "A loud note"), L("Vạch nhịp", "A bar line")], answer: 0, grade: 1),
        GMQuestion(text: L("Bộ phận nào đạp bằng chân trái?", "Which part is played with the left foot?"), options: [L("Hi-hat chân", "Hi-hat pedal"), "Kick", "Floor tom"], answer: 0, grade: 1),
        GMQuestion(text: L("Tom nào có âm trầm nhất?", "Which tom sounds lowest?"), options: ["Floor tom", "High tom", "Medium tom"], answer: 0, grade: 1),
        GMQuestion(text: L("Một nốt đen bằng bao nhiêu nốt móc kép?", "How many sixteenth notes make a quarter note?"), options: ["4", "2", "8"], answer: 0, grade: 2),
        GMQuestion(text: L("Chùm ba móc đơn chia một phách thành mấy phần?", "Into how many parts does an eighth-note triplet divide a beat?"), options: ["3", "2", "4"], answer: 0, grade: 2),
        GMQuestion(text: L("Flam là gì?", "What is a flam?"), options: [L("Một nốt hoa mỹ nhỏ ngay trước nốt chính", "A small grace note just before the main note"), L("Hai nốt đánh cùng lúc", "Two notes played together"), L("Cuộn dài", "A long roll")], answer: 0, grade: 2),
        GMQuestion(text: L("Dấu > trên nốt nghĩa là?", "What does > above a note mean?"), options: [L("Accent – đánh mạnh hơn", "Accent – play it louder"), L("Đánh nhỏ", "Play softly"), L("Lặp lại", "Repeat")], answer: 0, grade: 2),
        GMQuestion(text: L("Ghost note được ghi thế nào?", "How is a ghost note written?"), options: [L("Nốt trong ngoặc đơn", "A note in brackets"), L("Nốt có dấu >", "A note with >"), L("Nốt hình x", "An x notehead")], answer: 0, grade: 3),
        GMQuestion(text: L("Ký hiệu p (piano) nghĩa là?", "What does p (piano) mean?"), options: [L("Nhỏ", "Soft"), L("To", "Loud"), L("Nhanh dần", "Getting faster")], answer: 0, grade: 3),
        GMQuestion(text: L("Drag gồm những gì?", "What makes up a drag?"), options: [L("Hai nốt hoa mỹ trước nốt chính", "Two grace notes before the main note"), L("Một nốt hoa mỹ", "One grace note"), L("Bốn nốt đều", "Four even notes")], answer: 0, grade: 3),
        GMQuestion(text: L("Dấu lặp lại ô nhịp (%) nghĩa là?", "What does the bar-repeat sign (%) mean?"), options: [L("Chơi lại ô nhịp trước", "Play the previous bar again"), L("Dừng lại", "Stop"), L("Đổi tempo", "Change tempo")], answer: 0, grade: 3),
        GMQuestion(text: L("Crescendo nghĩa là?", "What does crescendo mean?"), options: [L("To dần", "Getting louder"), L("Nhỏ dần", "Getting softer"), L("Chậm dần", "Slowing down")], answer: 0, grade: 4),
        GMQuestion(text: L("Rim-shot là?", "What is a rim-shot?"), options: [L("Đánh mặt trống và vành cùng lúc", "Hitting the head and the rim together"), L("Đánh vào thân trống", "Hitting the shell"), L("Đánh nhẹ vành", "Tapping the rim lightly")], answer: 0, grade: 4),
        GMQuestion(text: L("Cross stick là?", "What is a cross stick?"), options: [L("Đặt dùi ngang mặt trống, gõ đuôi dùi vào vành", "Stick laid across the head, the butt clicks on the rim"), L("Đánh chéo tay", "Crossing your hands"), L("Đánh hai trống cùng lúc", "Hitting two drums at once")], answer: 0, grade: 4),
        GMQuestion(text: L("Nhịp 12/8 có mấy phách chính?", "How many main beats are in 12/8?"), options: [L("4 (mỗi phách 3 nốt móc đơn)", "4 (three eighth notes each)"), "12", "6"], answer: 0, grade: 5),
        GMQuestion(text: L("Sextuplet chia một phách thành?", "A sextuplet divides a beat into?"), options: [L("6 phần", "6 parts"), L("8 phần", "8 parts"), L("5 phần", "5 parts")], answer: 0, grade: 5),
        GMQuestion(text: L("Displacement (dịch nhịp) là?", "What is displacement?"), options: [L("Dịch một mẫu nhịp sang vị trí khác trong ô nhịp", "Moving a pattern to a different place in the bar"), L("Tăng tempo", "Speeding up"), L("Bỏ phách 1", "Leaving out beat 1")], answer: 0, grade: 6),
        GMQuestion(text: L("Metric modulation là?", "What is metric modulation?"), options: [L("Đổi cảm giác tempo dựa trên một giá trị nốt chung", "Changing the felt tempo through a shared note value"), L("Đổi số chỉ nhịp ngẫu nhiên", "Changing the time signature at random"), L("Ngừng giữa bài", "Stopping mid-song")], answer: 0, grade: 7),
        GMQuestion(text: L("Nhịp 7/8 thường được nhóm thế nào?", "How is 7/8 usually grouped?"), options: [L("2+2+3 hoặc 3+2+2", "2+2+3 or 3+2+2"), "4+3+1", L("Bảy phách đều nhấn", "Seven equally accented beats")], answer: 0, grade: 6),
        GMQuestion(text: L("Linear groove là?", "What is a linear groove?"), options: [L("Không có hai bộ phận đánh cùng lúc", "No two limbs play at the same time"), L("Chỉ dùng hi-hat", "Hi-hat only"), L("Groove nhịp thẳng 4/4", "A straight 4/4 groove")], answer: 0, grade: 6),
    ] }

    public static func questions(grade: Int, seed: UInt64) -> [GMQuestion] {
        var rng = LibraryRNG(seed: seed &+ UInt64(grade) &* 977)
        var available = pool.filter { $0.grade <= grade }
        var out: [GMQuestion] = []
        while out.count < 5, !available.isEmpty {
            let q = available.remove(at: Int(rng.nextUnit() * Double(available.count)) % available.count)
            // Shuffle options so the right answer isn't always first.
            var opts = q.options.enumerated().map { $0 }
            for i in opts.indices.reversed() { opts.swapAt(i, Int(rng.nextUnit() * Double(i + 1)) % (i + 1)) }
            out.append(GMQuestion(text: q.text, options: opts.map(\.element), answer: opts.firstIndex { $0.offset == q.answer }!, grade: q.grade))
        }
        return out
    }
}

/// Learns which MIDI note each pad of the user's kit sends (e.g. Roland TD-4K).
public struct MIDILearn: Sendable {
    public private(set) var map: [UInt8: Voice]
    private var awaiting: Voice?

    public init(map: [UInt8: Voice] = [:]) { self.map = map }

    public mutating func expect(_ v: Voice) { awaiting = v }

    /// While expecting a pad, the next note is assigned to it; otherwise returns the learned voice.
    public mutating func received(note: UInt8) -> Voice? {
        if let v = awaiting {
            map = map.filter { $0.value != v }
            map[note] = v
            awaiting = nil
            return v
        }
        return map[note]
    }
}
