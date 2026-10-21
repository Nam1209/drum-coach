import DrumAI
import DrumCore
import DrumAnalysis
import Charts
import SwiftUI

/// End of a run: the score, what kind of timing problem it was, and what to do next.
struct ResultsView: View {
    let stats: SessionStats
    let title: String
    let bpm: Double
    var input: AssessmentInput?
    var session: PracticeSession?
    var diagnosis: TimingDiagnosis?
    var samples: [RunSample] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("claude.model") private var model = ClaudeClient.defaultModel
    @State private var assessment: Assessment?
    @State private var usedAI = false
    @State private var asking = false
    @State private var aiError: String?
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    if let session { pointsView(session) }
                    if let d = diagnosis, d.kind != .notEnoughData { diagnosisView(d) }
                    if samples.count >= 4 { runChart }
                    findings
                    if let a = assessment { assessmentView(a) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Nhật ký", "Journal")).font(.headline)
                        TextField(L("Cảm nhận, chỗ khó, đau mỏi (tùy chọn)", "How it felt, tricky parts, aches (optional)"), text: $note, axis: .vertical)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.stage))
                    }
                }
                .padding(Theme.pagePadding)
            }
            .background(Theme.canvas)
            .navigationTitle(L("Kết quả", "Results"))
            .navigationBarTitleDisplayMode(.inline)
            .task { if let input, assessment == nil { assessment = AssessmentRequest.localFallback(input) } }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Xong", "Done")) { saveNote(); dismiss() } } }
        }
    }

    // MARK: Sections

    private var hero: some View {
        HStack(alignment: .bottom, spacing: 32) {
            Readout(value: "\(Int(stats.score.rounded()))%", caption: "\(title), \(Int(bpm)) BPM", size: 84, tint: scoreTint)
            Spacer()
            tally(good, L("đúng", "on time"), Theme.onTime)
            tally(stats.totalNotes - good - stats.missed, L("sớm/muộn", "early/late"), Theme.offTime)
            tally(stats.missed, L("trượt", "missed"), Theme.missed)
            tally(stats.extra, L("thừa", "extra"), .secondary)
        }
    }

    /// "+15 điểm" for this run, then the running total and the way to the next rank.
    private func pointsView(_ s: PracticeSession) -> some View {
        let total = HistoryStore.totalPoints(context)
        let rank = PracticeRank.for(points: total)
        let earned = s.points
        return Stage {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(earned >= 0 ? "+\(earned)" : "\(earned)").font(Theme.number(40))
                        .foregroundStyle(earned > 0 ? Theme.onTime : earned < 0 ? Theme.missed : .secondary)
                    Text(L("điểm lần này", "points this run")).font(.footnote).foregroundStyle(.secondary)
                    if s.completed, s.score >= PracticePoints.completionMinScore, s.seconds >= PracticePoints.minimumSeconds, s.missedFraction < 0.9 {
                        Label(L("+\(PracticePoints.completionBonus(seconds: s.seconds)) hoàn thành bài", "+\(PracticePoints.completionBonus(seconds: s.seconds)) for finishing"), systemImage: "flag.checkered")
                            .font(.caption.weight(.semibold)).foregroundStyle(Theme.onTime)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Hạng \(rank.level): \(rank.title)", "Rank \(rank.level): \(rank.title)")).font(.headline)
                    if let next = rank.next {
                        ProgressView(value: Double(total - rank.floor), total: Double(next - rank.floor)).tint(Theme.shell)
                        Text(L("\(total) điểm, còn \(next - total) điểm lên hạng \(rank.level + 1)", "\(total) points, \(next - total) to rank \(rank.level + 1)")).font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text(L("\(total) điểm, hạng cao nhất", "\(total) points, top rank")).font(.footnote).foregroundStyle(.secondary)
                    }
                    if s.seconds < PracticePoints.minimumSeconds {
                        Text(L("Dừng trước 10 giây: lần này không tính điểm.", "Stopped within 10 seconds: this run doesn't count.")).font(.footnote).foregroundStyle(.secondary)
                    } else if s.missedFraction >= 0.9 {
                        Text(L("App gần như không nghe thấy cú nào nên không tính điểm. Kiểm tra micro/kết nối trống (Hiệu chỉnh → Nghe thử).", "The app heard almost nothing, so this run doesn't count. Check the mic or kit connection (Calibration → Test listening).")).font(.footnote).foregroundStyle(.secondary)
                    } else if earned < 0 {
                        Text(L("Dưới 40% bị trừ một ít điểm. Giảm tempo 8–10 BPM rồi chơi lại để lấy lại điểm.", "Below 40% costs a few points. Lower the tempo by 8–10 BPM and play again to win them back.")).font(.footnote).foregroundStyle(.secondary)
                    } else if earned == 0 {
                        Text(L("40–60%: đang học, không cộng không trừ. Từ 60% (Pass) bắt đầu được cộng điểm.", "40–60%: learning zone, no points either way. From 60% (Pass) you start earning.")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func tally(_ n: Int, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(n)").font(Theme.number(30)).foregroundStyle(color)
            Text(label).font(.footnote).foregroundStyle(.secondary)
        }
    }

    /// Every note of the run: how early (below 0) or late (above 0), over time. Missed notes sit on the bottom edge.
    private var runChart: some View {
        let limit = max(60, (samples.compactMap(\.ms).map(abs).max() ?? 60).rounded(.up))
        return VStack(alignment: .leading, spacing: 8) {
            Text(L("Từng nốt trong lần chơi", "Every note in this run")).font(.headline)
            Chart {
                RuleMark(y: .value(L("Đúng nhịp", "On time"), 0)).foregroundStyle(Theme.hairline)
                ForEach(samples) { s in
                    PointMark(x: .value(L("Giây", "Seconds"), s.time), y: .value("ms", s.ms ?? -limit))
                        .foregroundStyle(s.grade.color)
                        .symbolSize(s.ms == nil ? 50 : 26)
                        .symbol(s.ms == nil ? .cross : .circle)
                }
            }
            .chartYScale(domain: -limit...limit)
            .chartYAxisLabel(L("sớm ← ms → muộn", "early ← ms → late"))
            .chartXAxisLabel(L("giây", "seconds"))
            .frame(height: 180)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.stage))
        }
    }

    private func diagnosisView(_ d: TimingDiagnosis) -> some View {
        let (icon, title, advice) = explain(d)
        return Stage {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(Theme.shell).frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(advice).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func explain(_ d: TimingDiagnosis) -> (String, String, String) {
        let mean = Int(d.meanMs.rounded()), drift = Int(abs(d.driftMsPerMinute).rounded()), spread = Int(d.spreadMs.rounded())
        switch d.kind {
        case .steady:
            return ("checkmark.circle", L("Nhịp vững", "Steady timing"), L("Lệch trung bình \(mean) ms, dao động ±\(spread) ms. Có thể tăng tempo.", "Average offset \(mean) ms, spread ±\(spread) ms. You can raise the tempo."))
        case .constantOffset:
            return ("dot.radiowaves.left.and.right", L("Lệch đều \(mean > 0 ? "+" : "")\(mean) ms từ đầu đến cuối", "Constant offset \(mean > 0 ? "+" : "")\(mean) ms throughout"),
                    L("Lỗi đều thường do cài đặt chứ không phải do bạn. Chạy lại Hiệu chỉnh độ trễ rồi chơi lại.", "A steady offset is usually a setup issue, not you. Re-run Latency calibration and play again."))
        case .dragging:
            return ("tortoise", L("Chậm dần khoảng \(drift) ms mỗi phút", "Dragging by about \(drift) ms per minute"),
                    L("Bạn bắt đầu đúng rồi trễ dần. Đếm thành tiếng và để tiếng click \"chìm\" vào cú đánh.", "You start on time, then fall behind. Count out loud and let the click sink into your stroke."))
        case .rushing:
            return ("hare", L("Nhanh dần khoảng \(drift) ms mỗi phút", "Rushing by about \(drift) ms per minute"),
                    L("Bạn bắt đầu đúng rồi vội dần. Thả lỏng vai, chờ click, thử bật Gap để giữ nhịp trong đầu.", "You start on time, then rush. Relax your shoulders, wait for the click, and try Gap to keep the beat in your head."))
        case .uneven:
            return ("waveform.path", L("Nhịp chưa đều (±\(spread) ms)", "Uneven timing (±\(spread) ms)"),
                    L("Không lệch hẳn về một phía nhưng dao động nhiều. Giảm 8 BPM và tập Count Coach.", "Not off to one side, but it swings a lot. Drop 8 BPM and practice Count Coach."))
        case .notEnoughData:
            return ("questionmark.circle", "", "")
        }
    }

    private var findings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Nhận xét", "Feedback")).font(.headline)
            Text(tendency)
            if let weakest { Text(weakest) }
            if let hands { Text(hands) }
            if let accent = stats.accentContrastDb {
                Text(accent < 4 ? L("Accent chưa rõ: chỉ to hơn nốt thường \(Int(accent.rounded())) dB. Nhấc dùi cao hơn ở nốt accent.", "Accent is weak: only \(Int(accent.rounded())) dB louder than normal notes. Lift the stick higher on accents.")
                                : L("Accent rõ ràng, to hơn nốt thường \(Int(accent.rounded())) dB.", "Clear accent, \(Int(accent.rounded())) dB louder than normal notes."))
            }
        }
        .foregroundStyle(.primary)
    }

    private func assessmentView(_ a: Assessment) -> some View {
        Stage {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(bandName(a.band)).font(.title2.weight(.bold))
                        .foregroundStyle(a.band == "Distinction" ? Theme.onTime : a.band == "Below Pass" ? Theme.missed : Theme.offTime)
                    Spacer()
                    Text(L("Khoảng Grade \(a.estimatedGrade)", "About Grade \(a.estimatedGrade)")).font(Theme.number(17)).foregroundStyle(.secondary)
                }
                Text(usedAI ? L("Nhận xét của Claude theo chuẩn Rockschool", "Claude's feedback, Rockschool standard") : L("Chấm theo chuẩn Rockschool trên máy", "Scored on-device, Rockschool standard"))
                    .font(.footnote).foregroundStyle(.secondary)
                Text(a.timingComment)
                ForEach(a.strengths, id: \.self) { Label($0, systemImage: "checkmark").foregroundStyle(Theme.onTime) }
                ForEach(a.weaknesses, id: \.self) { Label($0, systemImage: "exclamationmark").foregroundStyle(Theme.offTime) }
                ForEach(a.nextSteps, id: \.self) { Label($0, systemImage: "arrow.forward") }
                if let key = Keychain.get(Keychain.claudeKey), !key.isEmpty, !usedAI, let input {
                    Button(asking ? L("Claude đang xem…", "Claude is reviewing…") : L("Nhờ Claude nhận xét chi tiết", "Ask Claude for detailed feedback")) {
                        Task {
                            asking = true; defer { asking = false }
                            let out = await AssessmentRequest.runOrFallback(input, client: ClaudeClient(apiKey: key, model: model))
                            assessment = out.assessment; usedAI = out.usedAI; aiError = out.error
                            if out.usedAI, let s = session { s.assessmentData = try? JSONEncoder().encode(out.assessment); try? context.save() }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(asking)
                }
                if let aiError { Text(aiError).font(.footnote).foregroundStyle(Theme.offTime) }
            }
        }
    }

    // MARK: Helpers

    private var scoreTint: Color { stats.score > 90 ? Theme.onTime : stats.score >= 60 ? Theme.offTime : Theme.missed }

    private func bandName(_ band: String) -> String {
        switch band {
        case "Distinction": L("Xuất sắc (Distinction)", "Distinction")
        case "Merit": L("Khá (Merit)", "Merit")
        case "Pass": L("Đạt (Pass)", "Pass")
        default: L("Chưa đạt", "Not passed")
        }
    }

    private func saveNote() {
        let t = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        context.insert(JournalEntry(text: "\(title): \(t)"))
        try? context.save()
    }

    private var good: Int { Int((stats.accuracy * Double(stats.totalNotes)).rounded()) }

    private var tendency: String {
        let m = stats.meanOffsetMs
        if abs(m) < 8 { return L("Bám tempo tốt: lệch trung bình \(String(format: "%+.0f", m)) ms, dao động ±\(Int(stats.stdDevMs.rounded())) ms.", "Good tempo: average offset \(String(format: "%+.0f", m)) ms, spread ±\(Int(stats.stdDevMs.rounded())) ms.") }
        return m < 0 ? L("Bạn hay đánh sớm khoảng \(Int((-m).rounded())) ms. Thả lỏng, chờ click.", "You tend to play early by about \(Int((-m).rounded())) ms. Relax and wait for the click.")
                     : L("Bạn hay đánh muộn khoảng \(Int(m.rounded())) ms. Chuẩn bị dùi sớm hơn một chút.", "You tend to play late by about \(Int(m.rounded())) ms. Get your stick ready a bit earlier.")
    }

    private var weakest: String? {
        guard let (label, ms) = stats.byBeatPosition.max(by: { abs($0.value) < abs($1.value) }), abs(ms) >= 10 else { return nil }
        let name = label == "1" ? L("trên phách", "on the beat") : L("ở \"\(label)\"", "on \"\(label)\"")
        return L("Vị trí yếu nhất \(name): \(ms < 0 ? "sớm" : "muộn") \(Int(abs(ms).rounded())) ms.", "Weakest spot \(name): \(ms < 0 ? "early" : "late") by \(Int(abs(ms).rounded())) ms.")
    }

    private var hands: String? {
        guard let r = stats.byHand[.right], let l = stats.byHand[.left], abs(r - l) >= 10 else { return nil }
        return L("Tay \(abs(l) > abs(r) ? "trái" : "phải") lệch nhiều hơn (\(String(format: "%+.0f", abs(l) > abs(r) ? l : r)) ms).", "Your \(abs(l) > abs(r) ? "left" : "right") hand is off more (\(String(format: "%+.0f", abs(l) > abs(r) ? l : r)) ms).")
    }
}
