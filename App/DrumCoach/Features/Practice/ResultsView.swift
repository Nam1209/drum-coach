import DrumAI
import DrumAnalysis
import SwiftUI

/// End-of-run summary: big score, green/orange/red counts, tendency and weakest counting position.
struct ResultsView: View {
    let stats: SessionStats
    let title: String
    let bpm: Double
    var input: AssessmentInput?
    var session: PracticeSession?
    @Environment(\.dismiss) private var dismiss
    @AppStorage("claude.model") private var model = ClaudeClient.defaultModel
    @State private var assessment: Assessment?
    @State private var usedAI = false
    @State private var asking = false
    @State private var aiError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hoàn thành").foregroundStyle(.secondary)
                        Text("\(Int(stats.score.rounded()))%").font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(stats.score > 90 ? .green : stats.score >= 60 ? .orange : .red)
                        Text("\(title) · \(Int(bpm)) BPM").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                Section("Chi tiết") {
                    row("Đúng (xanh)", "\(good)", .green)
                    row("Sớm / muộn (cam)", "\(stats.totalNotes - good - stats.missed)", .orange)
                    row("Trượt (đỏ)", "\(stats.missed)", .red)
                    row("Đánh thừa", "\(stats.extra)", .secondary)
                }
                if let a = assessment {
                    Section(usedAI ? "Đánh giá của Claude" : "Đánh giá theo chuẩn Rockschool (cục bộ)") {
                        HStack {
                            Text(a.band).font(.title2.bold()).foregroundStyle(a.band == "Distinction" ? .green : a.band == "Below Pass" ? .red : .orange)
                            Spacer()
                            Text("≈ Grade \(a.estimatedGrade)").font(.headline)
                        }
                        Text(a.timingComment)
                        ForEach(a.strengths, id: \.self) { Label($0, systemImage: "checkmark.circle").foregroundStyle(.green) }
                        ForEach(a.weaknesses, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                        ForEach(a.nextSteps, id: \.self) { Label($0, systemImage: "arrow.right.circle") }
                        if let key = Keychain.get(Keychain.claudeKey), !key.isEmpty, !usedAI, let input {
                            Button(asking ? "Claude đang xem…" : "Nhờ Claude nhận xét chi tiết") {
                                Task {
                                    asking = true; defer { asking = false }
                                    let out = await AssessmentRequest.runOrFallback(input, client: ClaudeClient(apiKey: key, model: model))
                                    assessment = out.assessment; usedAI = out.usedAI; aiError = out.error
                                    if out.usedAI, let s = session { s.assessmentData = try? JSONEncoder().encode(out.assessment) }
                                }
                            }
                            .disabled(asking)
                        }
                        if let aiError { Text(aiError).font(.caption).foregroundStyle(.orange) }
                    }
                }
                Section("Nhận xét") {
                    Text(tendency)
                    if let weakest { Text(weakest) }
                    if let hands { Text(hands) }
                    if let accent = stats.accentContrastDb {
                        Text(accent < 4 ? "Accent chưa rõ: chỉ to hơn nốt thường \(Int(accent.rounded())) dB. Nhấc dùi cao hơn ở nốt accent."
                                        : "Accent rõ ràng (+\(Int(accent.rounded())) dB).")
                    }
                }
            }
            .navigationTitle("Kết quả")
            .task { if let input, assessment == nil { assessment = AssessmentRequest.localFallback(input) } }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
        }
    }

    private var good: Int { Int((stats.accuracy * Double(stats.totalNotes)).rounded()) }

    private var tendency: String {
        let m = stats.meanOffsetMs
        if abs(m) < 8 { return "Nhịp đều quanh tempo (lệch trung bình \(String(format: "%+.0f", m)) ms, dao động ±\(Int(stats.stdDevMs.rounded())) ms)." }
        return m < 0 ? "Bạn hay đánh SỚM khoảng \(Int((-m).rounded())) ms. Thả lỏng, chờ click." : "Bạn hay đánh MUỘN khoảng \(Int(m.rounded())) ms. Chuẩn bị dùi sớm hơn."
    }

    private var weakest: String? {
        guard let (label, ms) = stats.byBeatPosition.max(by: { abs($0.value) < abs($1.value) }), abs(ms) >= 10 else { return nil }
        let name = label == "1" ? "trên phách" : "ở \"\(label)\""
        return "Vị trí yếu nhất: \(name), \(ms < 0 ? "sớm" : "muộn") \(Int(abs(ms).rounded())) ms."
    }

    private var hands: String? {
        guard let r = stats.byHand[.right], let l = stats.byHand[.left], abs(r - l) >= 10 else { return nil }
        return "Tay \(abs(l) > abs(r) ? "trái" : "phải") lệch nhiều hơn (\(String(format: "%+.0f", abs(l) > abs(r) ? l : r)) ms)."
    }

    private func row(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
            Spacer()
            Text(value).monospacedDigit().bold()
        }
    }
}
