import Charts
import DrumAnalysis
import DrumCore
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
                Readout(value: "\(p.streakDays)", caption: L("ngày liên tiếp", "day streak"), size: 44)
                Readout(value: "\(Int(p.minutesThisWeek))", caption: L("phút trong 7 ngày qua", "minutes in the last 7 days"), size: 44)
                if let w = p.weakestBeatPosition { Readout(value: "\"\(w)\"", caption: L("vị trí yếu nhất", "weakest position"), size: 44, tint: Theme.offTime) }
            }
            CardSection(L("Tempo sạch theo thời gian", "Clean tempo over time"), footer: L("Tempo cao nhất mỗi ngày bạn chơi trên 90%.", "The highest tempo you played above 90% each day.")) {
                LabeledContent(L("Bài", "Exercise")) {
                    Picker(L("Bài", "Exercise"), selection: $exerciseId) {
                        Text(L("Bài tập nhiều nhất", "Most practiced exercise")).tag(String?.none)
                        ForEach(p.exerciseIds, id: \.id) { Text($0.title).tag(Optional($0.id)) }
                    }
                    .labelsHidden()
                }
                if let id = exerciseId ?? p.exerciseIds.first?.id {
                    let series = p.cleanTempoSeries(exerciseId: id)
                    if series.isEmpty { Text(L("Chưa có lần nào trên 90%.", "No run above 90% yet.")).foregroundStyle(.secondary) }
                    else {
                        Chart(series, id: \.date) { pt in
                            LineMark(x: .value(L("Ngày", "Date"), pt.date), y: .value("BPM", pt.bpm)).foregroundStyle(Theme.shell)
                            PointMark(x: .value(L("Ngày", "Date"), pt.date), y: .value("BPM", pt.bpm)).foregroundStyle(Theme.shell)
                        }
                        .chartYAxisLabel("BPM")
                        .frame(height: 220)
                    }
                } else {
                    Text(L("Chưa có buổi tập nào.", "No sessions yet.")).foregroundStyle(.secondary)
                }
            }
            CardSection(L("Sớm hay muộn theo vị trí đếm", "Early or late by counting position"), footer: L("30 ngày qua. Dưới 0 là sớm, trên 0 là muộn.", "Last 30 days. Below 0 is early, above 0 is late.")) {
                let pos = p.offsetByPosition.sorted { order($0.key) < order($1.key) }
                if pos.isEmpty { Text(L("Chưa có dữ liệu.", "No data yet.")).foregroundStyle(.secondary) }
                else {
                    Chart(pos, id: \.key) { item in
                        BarMark(x: .value(L("Vị trí", "Position"), item.key), y: .value("ms", item.value))
                            .foregroundStyle(abs(item.value) <= 15 ? Theme.onTime : Theme.offTime)
                    }
                    .chartYAxisLabel("ms")
                    .frame(height: 200)
                }
            }
            CardSection(L("Theo tuần", "By week")) {
                let weeks = digest.weekly.filter { $0.sessions > 0 }
                if weeks.isEmpty { Text(L("Chưa có dữ liệu.", "No data yet.")).foregroundStyle(.secondary) }
                else {
                    Chart(weeks, id: \.weekStart) { w in
                        BarMark(x: .value(L("Tuần", "Week"), w.weekStart, unit: .weekOfYear), y: .value(L("Phút", "Minutes"), w.minutes)).foregroundStyle(Theme.shell.opacity(0.7))
                    }
                    .chartYAxisLabel(L("phút", "min"))
                    .frame(height: 160)
                    Chart(weeks.filter { $0.meanOffsetMs != nil }, id: \.weekStart) { w in
                        LineMark(x: .value(L("Tuần", "Week"), w.weekStart, unit: .weekOfYear), y: .value(L("Lệch ms", "Offset ms"), w.meanOffsetMs ?? 0)).foregroundStyle(Theme.offTime)
                        RuleMark(y: .value("0", 0)).foregroundStyle(.secondary)
                    }
                    .chartYAxisLabel(L("lệch trung bình (ms)", "average offset (ms)"))
                    .frame(height: 160)
                }
            }
        }
    }

    private func order(_ k: String) -> Int { ["1": 0, "e": 1, "&": 2, "a": 3, "trip": 4, "let": 5][k] ?? 9 }
}
