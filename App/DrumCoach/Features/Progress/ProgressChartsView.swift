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
        List {
            Section {
                HStack(spacing: 32) {
                    stat("🔥 Chuỗi ngày", "\(p.streakDays)")
                    stat("⏱ 7 ngày qua", "\(Int(p.minutesThisWeek)) phút")
                    if let w = p.weakestBeatPosition { stat("Vị trí yếu nhất", "\"\(w)\"") }
                }
            }
            Section("Tempo sạch (> 90%) theo thời gian") {
                Picker("Bài", selection: $exerciseId) {
                    Text("Chọn bài").tag(String?.none)
                    ForEach(p.exerciseIds, id: \.id) { Text($0.title).tag(Optional($0.id)) }
                }
                if let id = exerciseId ?? p.exerciseIds.first?.id {
                    let series = p.cleanTempoSeries(exerciseId: id)
                    if series.isEmpty { Text("Chưa có lần nào trên 90%.").foregroundStyle(.secondary) }
                    else {
                        Chart(series, id: \.date) { pt in
                            LineMark(x: .value("Ngày", pt.date), y: .value("BPM", pt.bpm)).foregroundStyle(.orange)
                            PointMark(x: .value("Ngày", pt.date), y: .value("BPM", pt.bpm)).foregroundStyle(.orange)
                        }
                        .frame(height: 220)
                    }
                }
            }
            Section("Sớm / muộn theo vị trí đếm (30 ngày)") {
                let pos = p.offsetByPosition.sorted { order($0.key) < order($1.key) }
                if pos.isEmpty { Text("Chưa có dữ liệu.").foregroundStyle(.secondary) }
                else {
                    Chart(pos, id: \.key) { item in
                        BarMark(x: .value("Vị trí", item.key), y: .value("ms", item.value))
                            .foregroundStyle(abs(item.value) <= 15 ? Color.green : .orange)
                    }
                    .chartYAxisLabel("ms (âm = sớm, dương = muộn)")
                    .frame(height: 200)
                }
            }
            Section("Theo tuần") {
                let weeks = digest.weekly.filter { $0.sessions > 0 }
                if weeks.isEmpty { Text("Chưa có dữ liệu.").foregroundStyle(.secondary) }
                else {
                    Chart(weeks, id: \.weekStart) { w in
                        BarMark(x: .value("Tuần", w.weekStart, unit: .weekOfYear), y: .value("Phút", w.minutes)).foregroundStyle(.orange.opacity(0.6))
                    }
                    .frame(height: 160)
                    Chart(weeks.filter { $0.meanOffsetMs != nil }, id: \.weekStart) { w in
                        LineMark(x: .value("Tuần", w.weekStart, unit: .weekOfYear), y: .value("Lệch ms", w.meanOffsetMs ?? 0))
                        RuleMark(y: .value("0", 0)).foregroundStyle(.secondary)
                    }
                    .chartYAxisLabel("Lệch trung bình (ms)")
                    .frame(height: 160)
                }
            }
        }
        .navigationTitle("Biểu đồ")
    }

    private func order(_ k: String) -> Int { ["1": 0, "e": 1, "&": 2, "a": 3, "trip": 4, "let": 5][k] ?? 9 }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }
    }
}
