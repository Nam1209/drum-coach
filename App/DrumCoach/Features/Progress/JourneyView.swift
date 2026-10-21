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
        List {
            Picker("Khoảng thời gian", selection: $months) {
                Text("1 tháng").tag(1); Text("3 tháng").tag(3); Text("6 tháng").tag(6); Text("Từ đầu").tag(0)
            }
            .pickerStyle(.segmented)
            if TeacherConnection.isConfigured {
                Section {
                    Button("Nhờ thầy tổng kết giai đoạn") {
                        Task {
                            do { sendMessage = "Đã gửi \(try await TeacherConnection.sendPeriod(review)). Dán lời nhắn vào Claude." }
                            catch { sendMessage = "Không gửi được: \(error)" }
                        }
                    }
                    if let sendMessage { Text(sendMessage).font(.callout).foregroundStyle(.secondary) }
                }
            }
            Section("Tổng quan") {
                stat("Tổng giờ tập", String(format: "%.1f giờ", review.totalHours))
                stat("Số ngày tập", "\(review.daysPracticed)")
                stat("Chuỗi ngày dài nhất", "\(review.longestStreak) ngày")
                stat("Level", "\(review.levelStart) → \(review.levelEnd)")
                if let a = review.scoreStart, let b = review.scoreEnd { stat("Score trung bình", "\(Int(a))% → \(Int(b))%") }
                if let a = review.offsetStartMs, let b = review.offsetEndMs {
                    stat("Lệch trung bình", String(format: "%+.0f → %+.0f ms", a, b))
                }
            }
            if !review.levelsPassed.isEmpty {
                Section("Các mốc level") {
                    ForEach(review.levelsPassed, id: \.level) { m in
                        stat("Level \(m.level)", m.date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
            Section("Tempo sạch (> 90%) — đầu kỳ → cuối kỳ") {
                if review.exerciseDeltas.isEmpty { Text("Chưa có dữ liệu.").foregroundStyle(.secondary) }
                ForEach(review.exerciseDeltas, id: \.title) { d in
                    stat(d.title, "\(d.cleanBpmStart.map { "\(Int($0))" } ?? "–") → \(d.cleanBpmEnd.map { "\(Int($0))" } ?? "–") BPM")
                }
            }
            Section("Lỗi đã sửa được") {
                if review.fixedWeaknesses.isEmpty { Text("–").foregroundStyle(.secondary) }
                ForEach(review.fixedWeaknesses, id: \.self) { Label($0, systemImage: "checkmark.seal").foregroundStyle(.green) }
            }
            Section("Lỗi còn lại") {
                if review.remainingWeaknesses.isEmpty { Text("Không có lỗi lặp lại đáng kể 🎉").foregroundStyle(.secondary) }
                ForEach(review.remainingWeaknesses, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            }
        }
        .navigationTitle("Hành trình")
    }

    private func makeReview() -> PeriodReview {
        let records = HistoryStore.records(context)
        let to = Date()
        let from = months == 0 ? (records.first?.date ?? to) : Calendar.current.date(byAdding: .month, value: -months, to: to)!
        return HistorySummarizer.periodReview(records, levelHistory: SettingsStore.levelHistory, from: from, to: to, calendar: .current)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).bold().monospacedDigit() }
    }
}
