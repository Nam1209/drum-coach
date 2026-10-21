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
    static let pool: [GMQuestion] = [
        GMQuestion(text: "Trên khuông nhạc trống, kick (trống bass) nằm ở đâu?", options: ["Khe dưới cùng", "Khe thứ 3", "Trên khuông"], answer: 0, grade: 1),
        GMQuestion(text: "Snare nằm ở vị trí nào?", options: ["Khe thứ 3 từ dưới lên", "Dòng trên cùng", "Dưới khuông"], answer: 0, grade: 1),
        GMQuestion(text: "Nốt hình chữ x trên khuông thường là gì?", options: ["Chũm chọe (hi-hat, ride, crash)", "Tom", "Kick"], answer: 0, grade: 1),
        GMQuestion(text: "Số chỉ nhịp 4/4 nghĩa là?", options: ["4 phách nốt đen mỗi ô nhịp", "4 nốt móc đơn mỗi ô nhịp", "Tempo 44"], answer: 0, grade: 1),
        GMQuestion(text: "Một nốt đen bằng bao nhiêu nốt móc đơn?", options: ["2", "4", "3"], answer: 0, grade: 1),
        GMQuestion(text: "Dấu lặng là gì?", options: ["Ký hiệu không đánh trong một khoảng thời gian", "Nốt đánh mạnh", "Vạch nhịp"], answer: 0, grade: 1),
        GMQuestion(text: "Bộ phận nào đạp bằng chân trái?", options: ["Hi-hat chân", "Kick", "Floor tom"], answer: 0, grade: 1),
        GMQuestion(text: "Tom nào có âm trầm nhất?", options: ["Floor tom", "High tom", "Medium tom"], answer: 0, grade: 1),
        GMQuestion(text: "Một nốt đen bằng bao nhiêu nốt móc kép?", options: ["4", "2", "8"], answer: 0, grade: 2),
        GMQuestion(text: "Chùm ba móc đơn chia một phách thành mấy phần?", options: ["3", "2", "4"], answer: 0, grade: 2),
        GMQuestion(text: "Flam là gì?", options: ["Một nốt hoa mỹ nhỏ ngay trước nốt chính", "Hai nốt đánh cùng lúc", "Cuộn dài"], answer: 0, grade: 2),
        GMQuestion(text: "Dấu > trên nốt nghĩa là?", options: ["Accent – đánh mạnh hơn", "Đánh nhỏ", "Lặp lại"], answer: 0, grade: 2),
        GMQuestion(text: "Ghost note được ghi thế nào?", options: ["Nốt trong ngoặc đơn", "Nốt có dấu >", "Nốt hình x"], answer: 0, grade: 3),
        GMQuestion(text: "Ký hiệu p (piano) nghĩa là?", options: ["Nhỏ", "To", "Nhanh dần"], answer: 0, grade: 3),
        GMQuestion(text: "Drag gồm những gì?", options: ["Hai nốt hoa mỹ trước nốt chính", "Một nốt hoa mỹ", "Bốn nốt đều"], answer: 0, grade: 3),
        GMQuestion(text: "Dấu lặp lại ô nhịp (%) nghĩa là?", options: ["Chơi lại ô nhịp trước", "Dừng lại", "Đổi tempo"], answer: 0, grade: 3),
        GMQuestion(text: "Crescendo nghĩa là?", options: ["To dần", "Nhỏ dần", "Chậm dần"], answer: 0, grade: 4),
        GMQuestion(text: "Rim-shot là?", options: ["Đánh mặt trống và vành cùng lúc", "Đánh vào thân trống", "Đánh nhẹ vành"], answer: 0, grade: 4),
        GMQuestion(text: "Cross stick là?", options: ["Đặt dùi ngang mặt trống, gõ đuôi dùi vào vành", "Đánh chéo tay", "Đánh hai trống cùng lúc"], answer: 0, grade: 4),
        GMQuestion(text: "Nhịp 12/8 có mấy phách chính?", options: ["4 (mỗi phách 3 nốt móc đơn)", "12", "6"], answer: 0, grade: 5),
        GMQuestion(text: "Sextuplet chia một phách thành?", options: ["6 phần", "8 phần", "5 phần"], answer: 0, grade: 5),
        GMQuestion(text: "Displacement (dịch nhịp) là?", options: ["Dịch một mẫu nhịp sang vị trí khác trong ô nhịp", "Tăng tempo", "Bỏ phách 1"], answer: 0, grade: 6),
        GMQuestion(text: "Metric modulation là?", options: ["Đổi cảm giác tempo dựa trên một giá trị nốt chung", "Đổi số chỉ nhịp ngẫu nhiên", "Ngừng giữa bài"], answer: 0, grade: 7),
        GMQuestion(text: "Nhịp 7/8 thường được nhóm thế nào?", options: ["2+2+3 hoặc 3+2+2", "4+3+1", "Bảy phách đều nhấn"], answer: 0, grade: 6),
        GMQuestion(text: "Linear groove là?", options: ["Không có hai bộ phận đánh cùng lúc", "Chỉ dùng hi-hat", "Groove nhịp thẳng 4/4"], answer: 0, grade: 6),
    ]

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

/// Learns which MIDI note each pad of the user's kit sends (e.g. Roland TD-7).
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
