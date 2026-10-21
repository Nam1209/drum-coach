import DrumAI
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
                    if let d = diagnosis, d.kind != .notEnoughData { diagnosisView(d) }
                    if samples.count >= 4 { runChart }
                    findings
                    if let a = assessment { assessmentView(a) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nhật ký").font(.headline)
                        TextField("Cảm nhận, chỗ khó, đau mỏi (tùy chọn)", text: $note, axis: .vertical)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.stage))
                    }
                }
                .padding(Theme.pagePadding)
            }
            .background(Theme.canvas)
            .navigationTitle("Kết quả")
            .navigationBarTitleDisplayMode(.inline)
            .task { if let input, assessment == nil { assessment = AssessmentRequest.localFallback(input) } }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { saveNote(); dismiss() } } }
        }
    }

    // MARK: Sections

    private var hero: some View {
        HStack(alignment: .bottom, spacing: 32) {
            Readout(value: "\(Int(stats.score.rounded()))%", caption: "\(title), \(Int(bpm)) BPM", size: 84, tint: scoreTint)
            Spacer()
            tally(good, "đúng", Theme.onTime)
            tally(stats.totalNotes - good - stats.missed, "sớm/muộn", Theme.offTime)
            tally(stats.missed, "trượt", Theme.missed)
            tally(stats.extra, "thừa", .secondary)
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
            Text("Từng nốt trong lần chơi").font(.headline)
            Chart {
                RuleMark(y: .value("Đúng nhịp", 0)).foregroundStyle(Theme.hairline)
                ForEach(samples) { s in
                    PointMark(x: .value("Giây", s.time), y: .value("ms", s.ms ?? -limit))
                        .foregroundStyle(s.grade.color)
                        .symbolSize(s.ms == nil ? 50 : 26)
                        .symbol(s.ms == nil ? .cross : .circle)
                }
            }
            .chartYScale(domain: -limit...limit)
            .chartYAxisLabel("sớm ← ms → muộn")
            .chartXAxisLabel("giây")
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
            return ("checkmark.circle", "Nhịp vững", "Lệch trung bình \(mean) ms, dao động ±\(spread) ms. Có thể tăng tempo.")
        case .constantOffset:
            return ("dot.radiowaves.left.and.right", "Lệch đều \(mean > 0 ? "+" : "")\(mean) ms từ đầu đến cuối",
                    "Lỗi đều thường do cài đặt chứ không phải do bạn. Chạy lại Hiệu chỉnh độ trễ rồi chơi lại.")
        case .dragging:
            return ("tortoise", "Chậm dần khoảng \(drift) ms mỗi phút",
                    "Bạn bắt đầu đúng rồi trễ dần. Đếm thành tiếng và để tiếng click \"chìm\" vào cú đánh.")
        case .rushing:
            return ("hare", "Nhanh dần khoảng \(drift) ms mỗi phút",
                    "Bạn bắt đầu đúng rồi vội dần. Thả lỏng vai, chờ click, thử bật Gap để giữ nhịp trong đầu.")
        case .uneven:
            return ("waveform.path", "Nhịp chưa đều (±\(spread) ms)",
                    "Không lệch hẳn về một phía nhưng dao động nhiều. Giảm 8 BPM và tập Count Coach.")
        case .notEnoughData:
            return ("questionmark.circle", "", "")
        }
    }

    private var findings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nhận xét").font(.headline)
            Text(tendency)
            if let weakest { Text(weakest) }
            if let hands { Text(hands) }
            if let accent = stats.accentContrastDb {
                Text(accent < 4 ? "Accent chưa rõ: chỉ to hơn nốt thường \(Int(accent.rounded())) dB. Nhấc dùi cao hơn ở nốt accent."
                                : "Accent rõ ràng, to hơn nốt thường \(Int(accent.rounded())) dB.")
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
                    Text("Khoảng Grade \(a.estimatedGrade)").font(Theme.number(17)).foregroundStyle(.secondary)
                }
                Text(usedAI ? "Nhận xét của Claude theo chuẩn Rockschool" : "Chấm theo chuẩn Rockschool trên máy")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(a.timingComment)
                ForEach(a.strengths, id: \.self) { Label($0, systemImage: "checkmark").foregroundStyle(Theme.onTime) }
                ForEach(a.weaknesses, id: \.self) { Label($0, systemImage: "exclamationmark").foregroundStyle(Theme.offTime) }
                ForEach(a.nextSteps, id: \.self) { Label($0, systemImage: "arrow.forward") }
                if let key = Keychain.get(Keychain.claudeKey), !key.isEmpty, !usedAI, let input {
                    Button(asking ? "Claude đang xem…" : "Nhờ Claude nhận xét chi tiết") {
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
        case "Distinction": "Xuất sắc (Distinction)"
        case "Merit": "Khá (Merit)"
        case "Pass": "Đạt (Pass)"
        default: "Chưa đạt"
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
        if abs(m) < 8 { return "Bám tempo tốt: lệch trung bình \(String(format: "%+.0f", m)) ms, dao động ±\(Int(stats.stdDevMs.rounded())) ms." }
        return m < 0 ? "Bạn hay đánh sớm khoảng \(Int((-m).rounded())) ms. Thả lỏng, chờ click."
                     : "Bạn hay đánh muộn khoảng \(Int(m.rounded())) ms. Chuẩn bị dùi sớm hơn một chút."
    }

    private var weakest: String? {
        guard let (label, ms) = stats.byBeatPosition.max(by: { abs($0.value) < abs($1.value) }), abs(ms) >= 10 else { return nil }
        let name = label == "1" ? "trên phách" : "ở \"\(label)\""
        return "Vị trí yếu nhất \(name): \(ms < 0 ? "sớm" : "muộn") \(Int(abs(ms).rounded())) ms."
    }

    private var hands: String? {
        guard let r = stats.byHand[.right], let l = stats.byHand[.left], abs(r - l) >= 10 else { return nil }
        return "Tay \(abs(l) > abs(r) ? "trái" : "phải") lệch nhiều hơn (\(String(format: "%+.0f", abs(l) > abs(r) ? l : r)) ms)."
    }
}
