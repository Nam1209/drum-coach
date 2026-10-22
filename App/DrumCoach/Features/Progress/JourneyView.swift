import DrumAnalysis
import DrumCore
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
                Picker(L("Khoảng thời gian", "Time period"), selection: $months) {
                    Text(L("1 tháng", "1 month")).tag(1); Text(L("3 tháng", "3 months")).tag(3); Text(L("6 tháng", "6 months")).tag(6); Text(L("Từ đầu", "All time")).tag(0)
                }
                .pickerStyle(.segmented).frame(maxWidth: 420)
                Spacer()
                if TeacherConnection.isConfigured {
                    Button(L("Nhờ thầy tổng kết giai đoạn", "Ask the teacher to review this period")) {
                        Task {
                            do { sendMessage = L("Đã gửi \(try await TeacherConnection.sendPeriod(review)). Dán lời nhắn vào Claude.", "Sent \(try await TeacherConnection.sendPeriod(review)). Paste the message into Claude.") }
                            catch { sendMessage = L("Không gửi được: \(Friendly.message(error))", "Couldn't send: \(Friendly.message(error))") }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            if let sendMessage { Text(sendMessage).font(.callout).foregroundStyle(.secondary) }
            HStack(alignment: .bottom, spacing: 40) {
                Readout(value: String(format: "%.1f", review.totalHours), caption: L("giờ tập", "hours practiced"), size: 44)
                Readout(value: "\(review.daysPracticed)", caption: L("ngày tập", "days practiced"), size: 44)
                Readout(value: "\(review.longestStreak)", caption: L("ngày liên tiếp dài nhất", "longest streak (days)"), size: 44)
                Readout(value: "\(review.levelStart)→\(review.levelEnd)", caption: "Grade", size: 44, tint: Theme.shell)
            }
            HStack(alignment: .top, spacing: 22) {
                VStack(spacing: 22) {
                    CardSection(L("Đầu kỳ và cuối kỳ", "Start and end of period")) {
                        if let a = review.scoreStart, let b = review.scoreEnd { row(L("Điểm trung bình", "Average score"), "\(Int(a))% → \(Int(b))%") }
                        if let a = review.offsetStartMs, let b = review.offsetEndMs { row(L("Lệch trung bình", "Average offset"), String(format: "%+.0f → %+.0f ms", a, b)) }
                        ForEach(review.exerciseDeltas, id: \.title) { d in
                            row(d.title, "\(d.cleanBpmStart.map { "\(Int($0))" } ?? "–") → \(d.cleanBpmEnd.map { "\(Int($0))" } ?? "–") BPM")
                        }
                        if review.scoreStart == nil, review.exerciseDeltas.isEmpty { Text(L("Chưa có dữ liệu.", "No data yet.")).foregroundStyle(.secondary) }
                    }
                    if !review.levelsPassed.isEmpty {
                        CardSection(L("Các mốc Grade", "Grade milestones")) {
                            ForEach(review.levelsPassed, id: \.level) { m in row("Grade \(m.level)", m.date.formatted(date: .abbreviated, time: .omitted)) }
                        }
                    }
                }
                VStack(spacing: 22) {
                    CardSection(L("Lỗi đã sửa được", "Fixed weaknesses")) {
                        if review.fixedWeaknesses.isEmpty { Text(L("Chưa có", "None yet")).foregroundStyle(.secondary) }
                        ForEach(review.fixedWeaknesses, id: \.self) { Label($0, systemImage: "checkmark.circle").foregroundStyle(Theme.onTime) }
                    }
                    CardSection(L("Lỗi còn lại", "Remaining weaknesses")) {
                        if review.remainingWeaknesses.isEmpty { Text(L("Không có lỗi lặp lại đáng kể", "No notable recurring weaknesses")).foregroundStyle(.secondary) }
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
