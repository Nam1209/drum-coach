import Charts
import DrumAnalysis
import SwiftData
import SwiftUI

/// Streak, weekly minutes, clean tempo over time, early/late by counting position, weekly timing trend.
struct ProgressChartsView: View {
    @Environment(\.modelContext) private var context
    @State private var exerciseId: String?

    var body: some View {
        let records = HistoryStore.records(context)
        let p = ProgressSummary(records: records, now: Date(), calendar: .current)
        let digest = HistorySummarizer.digest(records, journal: [], currentLevel: SettingsStore.currentGrade, now: Date(), calendar: .current)
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .bottom, spacing: 40) {
                Readout(value: "\(p.streakDays)", caption: "ngày liên tiếp", size: 44)
                Readout(value: "\(Int(p.minutesThisWeek))", caption: "phút trong 7 ngày qua", size: 44)
                if let w = p.weakestBeatPosition { Readout(value: "\"\(w)\"", caption: "vị trí yếu nhất", size: 44, tint: Theme.offTime) }
            }
            CardSection("Tempo sạch theo thời gian", footer: "Tempo cao nhất mỗi ngày bạn chơi trên 90%.") {
                LabeledContent("Bài") {
                    Picker("Bài", selection: $exerciseId) {
                        Text("Bài tập nhiều nhất").tag(String?.none)
                        ForEach(p.exerciseIds, id: \.id) { Text($0.title).tag(Optional($0.id)) }
                    }
                    .labelsHidden()
                }
                if let id = exerciseId ?? p.exerciseIds.first?.id {
                    let series = p.cleanTempoSeries(exerciseId: id)
                    if series.isEmpty { Text("Chưa có lần nào trên 90%.").foregroundStyle(.secondary) }
                    else {
                        Chart(series, id: \.date) { pt in
                            LineMark(x: .value("Ngày", pt.date), y: .value("BPM", pt.bpm)).foregroundStyle(Theme.shell)
                            PointMark(x: .value("Ngày", pt.date), y: .value("BPM", pt.bpm)).foregroundStyle(Theme.shell)
                        }
                        .chartYAxisLabel("BPM")
                        .frame(height: 220)
                    }
                } else {
                    Text("Chưa có buổi tập nào.").foregroundStyle(.secondary)
                }
            }
            CardSection("Sớm hay muộn theo vị trí đếm", footer: "30 ngày qua. Dưới 0 là sớm, trên 0 là muộn.") {
                let pos = p.offsetByPosition.sorted { order($0.key) < order($1.key) }
                if pos.isEmpty { Text("Chưa có dữ liệu.").foregroundStyle(.secondary) }
                else {
                    Chart(pos, id: \.key) { item in
                        BarMark(x: .value("Vị trí", item.key), y: .value("ms", item.value))
                            .foregroundStyle(abs(item.value) <= 15 ? Theme.onTime : Theme.offTime)
                    }
                    .chartYAxisLabel("ms")
                    .frame(height: 200)
                }
            }
            CardSection("Theo tuần") {
                let weeks = digest.weekly.filter { $0.sessions > 0 }
                if weeks.isEmpty { Text("Chưa có dữ liệu.").foregroundStyle(.secondary) }
                else {
                    Chart(weeks, id: \.weekStart) { w in
                        BarMark(x: .value("Tuần", w.weekStart, unit: .weekOfYear), y: .value("Phút", w.minutes)).foregroundStyle(Theme.shell.opacity(0.7))
                    }
                    .chartYAxisLabel("phút")
                    .frame(height: 160)
                    Chart(weeks.filter { $0.meanOffsetMs != nil }, id: \.weekStart) { w in
                        LineMark(x: .value("Tuần", w.weekStart, unit: .weekOfYear), y: .value("Lệch ms", w.meanOffsetMs ?? 0)).foregroundStyle(Theme.offTime)
                        RuleMark(y: .value("0", 0)).foregroundStyle(.secondary)
                    }
                    .chartYAxisLabel("lệch trung bình (ms)")
                    .frame(height: 160)
                }
            }
        }
    }

    private func order(_ k: String) -> Int { ["1": 0, "e": 1, "&": 2, "a": 3, "trip": 4, "let": 5][k] ?? 9 }
}
