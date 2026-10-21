import DrumAnalysis
import SwiftData
import SwiftUI

/// "Hành trình": before → after over 1/3/6 months or since the start.
struct JourneyView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<PracticeSession> { $0.isLevelTest }) private var levelAttempts: [PracticeSession]
    @State private var months = 3
    @State private var sendMessage: String?

    var body: some View {
        let review = makeReview()
        VStack(alignment: .leading, spacing: 26) {
            HStack {
                Picker("Khoảng thời gian", selection: $months) {
                    Text("1 tháng").tag(1); Text("3 tháng").tag(3); Text("6 tháng").tag(6); Text("Từ đầu").tag(0)
                }
                .pickerStyle(.segmented).frame(maxWidth: 420)
                Spacer()
                if TeacherConnection.isConfigured {
                    Button("Nhờ thầy tổng kết giai đoạn") {
                        Task {
                            do { sendMessage = "Đã gửi \(try await TeacherConnection.sendPeriod(review)). Dán lời nhắn vào Claude." }
                            catch { sendMessage = "Không gửi được: \(Friendly.message(error))" }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            if let sendMessage { Text(sendMessage).font(.callout).foregroundStyle(.secondary) }
            HStack(alignment: .bottom, spacing: 40) {
                Readout(value: String(format: "%.1f", review.totalHours), caption: "giờ tập", size: 44)
                Readout(value: "\(review.daysPracticed)", caption: "ngày tập", size: 44)
                Readout(value: "\(review.longestStreak)", caption: "ngày liên tiếp dài nhất", size: 44)
                Readout(value: "\(review.levelStart)→\(review.levelEnd)", caption: "Grade", size: 44, tint: Theme.shell)
            }
            HStack(alignment: .top, spacing: 22) {
                VStack(spacing: 22) {
                    CardSection("Đầu kỳ và cuối kỳ") {
                        if let a = review.scoreStart, let b = review.scoreEnd { row("Điểm trung bình", "\(Int(a))% → \(Int(b))%") }
                        if let a = review.offsetStartMs, let b = review.offsetEndMs { row("Lệch trung bình", String(format: "%+.0f → %+.0f ms", a, b)) }
                        ForEach(review.exerciseDeltas, id: \.title) { d in
                            row(d.title, "\(d.cleanBpmStart.map { "\(Int($0))" } ?? "–") → \(d.cleanBpmEnd.map { "\(Int($0))" } ?? "–") BPM")
                        }
                        if review.scoreStart == nil, review.exerciseDeltas.isEmpty { Text("Chưa có dữ liệu.").foregroundStyle(.secondary) }
                    }
                    if !review.levelsPassed.isEmpty {
                        CardSection("Các mốc Grade") {
                            ForEach(review.levelsPassed, id: \.level) { m in row("Grade \(m.level)", m.date.formatted(date: .abbreviated, time: .omitted)) }
                        }
                    }
                }
                VStack(spacing: 22) {
                    CardSection("Lỗi đã sửa được") {
                        if review.fixedWeaknesses.isEmpty { Text("Chưa có").foregroundStyle(.secondary) }
                        ForEach(review.fixedWeaknesses, id: \.self) { Label($0, systemImage: "checkmark.circle").foregroundStyle(Theme.onTime) }
                    }
                    CardSection("Lỗi còn lại") {
                        if review.remainingWeaknesses.isEmpty { Text("Không có lỗi lặp lại đáng kể").foregroundStyle(.secondary) }
                        ForEach(review.remainingWeaknesses, id: \.self) { Label($0, systemImage: "exclamationmark.circle").foregroundStyle(Theme.offTime) }
                    }
                }
            }
        }
    }

    private func makeReview() -> PeriodReview {
        let records = HistoryStore.records(context)
        let to = Date()
        let from = months == 0 ? (records.first?.date ?? to) : Calendar.current.date(byAdding: .month, value: -months, to: to)!
        return HistorySummarizer.periodReview(records, levelHistory: SettingsStore.levelHistory, from: from, to: to, calendar: .current)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).font(Theme.number(16, weight: .medium)) }
    }
}
