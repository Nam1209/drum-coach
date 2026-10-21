import DrumCore

/// How to spend a day's practice time, and roughly how long the road to a grade is at that pace.
/// The pace figures are rules of thumb for an adult learner practising most days, not measurements.
public struct DailyBudget: Sendable {
    public struct Block: Sendable, Hashable {
        public let title: String
        public let minutes: Int
        public let detail: String
    }

    public static let options = [30, 60, 120, 240]

    public let minutes: Int
    /// Practice sittings, with `breakMinutes` between them.
    public let sessions: [[Block]]
    public let breakMinutes: Int
    /// Months per grade up to Grade 5; Grades 6–8 take half as long again.
    public let monthsPerGrade: ClosedRange<Double>
    public let restDaysPerWeek: Int
    public let warnings: [String]

    public var practiceMinutes: Int { sessions.joined().reduce(0) { $0 + $1.minutes } }

    /// Whole months to reach `target` from `current` at this pace.
    public func monthsToGrade(_ target: Int, from current: Int) -> ClosedRange<Int> {
        guard target > current else { return 0...0 }
        let units = (current + 1...target).reduce(0.0) { $0 + ($1 >= 6 ? 1.5 : 1) }
        return Int((units * monthsPerGrade.lowerBound).rounded(.up))...Int((units * monthsPerGrade.upperBound).rounded(.up))
    }

    /// The plan for the closest option to `minutes`.
    public static func plan(minutes: Int) -> DailyBudget {
        let m = options.min { abs($0 - minutes) < abs($1 - minutes) || (abs($0 - minutes) == abs($1 - minutes) && $0 < $1) }!
        let warm = { (n: Int) in Block(title: L("Khởi động", "Warm-up"), minutes: n, detail: L("Rudiment chậm trên pad, thả lỏng vai và cổ tay", "Slow rudiments on the pad, loose shoulders and wrists")) }
        let tech = { (n: Int) in Block(title: L("Kỹ thuật", "Technique"), minutes: n, detail: L("Stick Control và rudiment theo máy nhịp", "Stick Control and rudiments to the click")) }
        let main = { (n: Int) in Block(title: L("Bài chính", "Main work"), minutes: n, detail: L("Bài kiểm tra cấp độ hoặc bài thầy giao, dùng Lặp ô nhịp cho chỗ khó", "Level tests or the teacher's exercises; loop the hard bars")) }
        let read = { (n: Int) in Block(title: L("Đọc nhạc và nghe chép", "Reading and dictation"), minutes: n, detail: L("Đọc nhạc ngẫu nhiên, Nghe chép nhịp, Count Coach", "Random reading, rhythm dictation, Count Coach")) }
        let groove = { (n: Int) in Block(title: L("Groove và fill", "Grooves and fills"), minutes: n, detail: L("Groove theo cấp độ, hoán vị kick/snare", "Grade grooves, kick/snare permutations")) }
        let songs = { (n: Int) in Block(title: L("Chơi theo bài hát", "Play-along"), minutes: n, detail: L("Bài nhập từ MIDI hoặc backing track", "MIDI imports or backing tracks")) }
        let review = { (n: Int) in Block(title: L("Ôn chỗ yếu", "Weak spots"), minutes: n, detail: L("Học tự động trên bài điểm thấp nhất tuần", "Auto-learn on the week's lowest-scoring exercise")) }
        let breakAdvice = L("Nghỉ giữa các buổi: đứng dậy, uống nước, giãn cổ tay và cẳng tay.", "Between sittings: stand up, drink water, stretch wrists and forearms.")
        switch m {
        case 30:
            return DailyBudget(minutes: 30, sessions: [[warm(5), tech(10), main(10), groove(5)]], breakMinutes: 0,
                               monthsPerGrade: 5...6, restDaysPerWeek: 0,
                               warnings: [L("Ít thời gian thì tập đều mỗi ngày quan trọng hơn tập dài cuối tuần.", "With little time, every day beats a long weekend session.")])
        case 60:
            return DailyBudget(minutes: 60, sessions: [[warm(10), tech(15), main(20), read(10), groove(5)]], breakMinutes: 0,
                               monthsPerGrade: 3...4, restDaysPerWeek: 0, warnings: [])
        case 120:
            return DailyBudget(minutes: 120, sessions: [[warm(10), tech(20), main(30)], [read(15), groove(20), songs(15)]], breakMinutes: 10,
                               monthsPerGrade: 2...3, restDaysPerWeek: 1, warnings: [breakAdvice])
        default:
            return DailyBudget(minutes: 240, sessions: [[warm(10), tech(35)], [main(45)], [read(25), groove(20)], [songs(30), review(15)]],
                               breakMinutes: 20, monthsPerGrade: 1.5...2.5, restDaysPerWeek: 1,
                               warnings: [breakAdvice,
                                          L("Đau cổ tay hoặc cẳng tay thì dừng ngay. Đau quá 2 ngày nên đi khám.", "Stop at any wrist or forearm pain. See a doctor if it lasts over 2 days."),
                                          L("Nghỉ hẳn ít nhất 1 ngày mỗi tuần để gân và cơ hồi phục.", "Take at least one full day off a week so tendons can recover."),
                                          L("Tập 4 tiếng không nhanh gấp đôi 2 tiếng: sau khoảng 2 tiếng, độ tập trung giảm và dễ tập sai.", "Four hours is not twice as fast as two: after about two hours focus drops and mistakes creep in.")])
        }
    }
}
