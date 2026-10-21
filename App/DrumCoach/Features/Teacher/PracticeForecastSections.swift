import Charts
import DrumAI
import DrumAnalysis
import DrumLibrary
import SwiftData
import SwiftUI

/// Teacher screen: how to spend the chosen daily time, and where this learner is heading at their own pace.
struct PracticeForecastSections: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<PracticeSession> { $0.isLevelTest }) private var attempts: [PracticeSession]
    @Query(sort: \PracticeSession.date) private var sessions: [PracticeSession]
    @AppStorage("dailyBudgetMinutes") private var budgetMinutes = 60
    @State private var windowDays = 7
    @State private var applied = false

    var body: some View {
        let evidence = makeEvidence()
        let plan = DailyBudget.plan(minutes: budgetMinutes)
        HStack(alignment: .top, spacing: 22) {
            budgetSection(plan, evidence)
            forecastSection(evidence, plan)
        }
    }

    // MARK: Budget

    private func budgetSection(_ plan: DailyBudget, _ e: ForecastEvidence) -> some View {
        CardSection("Tập bao lâu mỗi ngày?",
                    footer: "Số tháng tính theo tốc độ học, điểm và số bài đã đạt của chính bạn. Đây là ước tính, không phải cam kết.") {
            Picker("Thời lượng", selection: $budgetMinutes) {
                Text("30 phút").tag(30); Text("1 tiếng").tag(60); Text("2 tiếng").tag(120); Text("4 tiếng").tag(240)
            }
            .pickerStyle(.segmented)
            ForEach(Array(plan.sessions.enumerated()), id: \.offset) { k, blocks in
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.sessions.count > 1 ? "Buổi \(k + 1), \(blocks.reduce(0) { $0 + $1.minutes }) phút" : "\(blocks.reduce(0) { $0 + $1.minutes }) phút")
                        .font(.footnote).foregroundStyle(.secondary)
                    BlockBar(blocks: blocks)
                    ForEach(blocks, id: \.self) { b in
                        (Text(b.title).bold() + Text(" \(b.minutes) phút  ") + Text(b.detail).foregroundStyle(.secondary)).font(.callout)
                    }
                    if k < plan.sessions.count - 1 { Text("Nghỉ \(plan.breakMinutes) phút").font(.footnote).foregroundStyle(.secondary) }
                }
                .padding(.vertical, 4)
            }
            let f = e.forecast.with(minutesPerDay: Double(budgetMinutes))
            HStack(alignment: .bottom, spacing: 32) {
                if e.forecast.currentGrade < 8 {
                    Readout(value: span(f.months(toReach: e.forecast.currentGrade + 1)), caption: "tháng lên Grade \(e.forecast.currentGrade + 1)", size: 34)
                }
                Readout(value: span(f.months(toReach: 8)), caption: "tháng tới Grade 8", size: 34)
                Readout(value: "\(plan.restDaysPerWeek)", caption: "ngày nghỉ mỗi tuần", size: 34)
            }
            ForEach(plan.warnings, id: \.self) { Text($0).font(.callout).foregroundStyle(budgetMinutes == 240 ? Theme.offTime : .secondary) }
            Button(applied ? "Đã đặt cho kế hoạch tuần tới" : "Dùng mức này cho kế hoạch") {
                var p = TeacherConnection.profile
                p.minutesPerDay = budgetMinutes
                TeacherConnection.profile = p
                applied = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(applied)
        }
        .onChange(of: budgetMinutes) { applied = false }
    }

    // MARK: Forecast

    private func forecastSection(_ e: ForecastEvidence, _ plan: DailyBudget) -> some View {
        CardSection("Dự đoán cho riêng bạn",
                    footer: "Dựa trên thời gian tập, số bài đã đạt, tốc độ lên các Grade trước, điểm trung bình và tempo của bạn. Càng tập lâu với app, dự đoán càng sát.") {
            Picker("Khoảng thời gian", selection: $windowDays) { Text("7 ngày qua").tag(7); Text("30 ngày qua").tag(30) }
                .pickerStyle(.segmented)
            if sessions.isEmpty {
                Text("Chưa có buổi tập nào. Tập vài buổi để app có dữ liệu dự đoán cho riêng bạn.").foregroundStyle(.secondary)
            } else {
                minutesChart(e)
                let f = e.forecast
                factor("Thời gian", "\(Int(f.minutesPerDay.rounded())) phút/ngày, tập \(e.daysPracticed)/\(e.windowDays) ngày",
                       Text(ProgressForecast.typicalMonthsPerGrade(minutes: f.minutesPerDay).isFinite
                            ? "thường mất \(oneDecimal(ProgressForecast.typicalMonthsPerGrade(minutes: f.minutesPerDay))) tháng mỗi Grade"
                            : "chưa tập trong \(e.windowDays) ngày qua nên chưa dự đoán được").foregroundStyle(.secondary))
                if f.testsInNextGrade > 0 {
                    factor("Đã hoàn thành", "\(f.testsPassed)/\(f.testsInNextGrade) bài kiểm tra Grade \(f.currentGrade + 1)",
                           Text("bắt đầu từ \(oneDecimal(f.position(afterMonths: 0)))").foregroundStyle(.secondary))
                }
                factor("Tốc độ học", f.pastGrades.isEmpty ? "Chưa lên Grade nào trong app" : f.pastGrades.map { "Grade \($0.grade) mất \(oneDecimal($0.months)) tháng" }.joined(separator: ", "),
                       effect(f.paceFactor, faster: "nhanh hơn %d%% so với người tập cùng thời gian", slower: "chậm hơn %d%% so với người tập cùng thời gian"))
                if let s = f.recentAverageScore {
                    factor("Chất lượng", "điểm trung bình \(Int(s.rounded()))%",
                           effect(f.qualityFactor, faster: "tập sạch, nhanh hơn %d%%", slower: s < 60 ? "dưới 60% nhiều, chậm hơn %d%%" : "còn ẩu, chậm hơn %d%%"))
                }
                if let bpm = f.currentBpm {
                    factor("Tempo", "\(e.trackedTitle ?? "Bài chính") \(Int(bpm)) BPM" + (f.bpmPerWeek.map { ", tăng \(oneDecimal($0)) BPM mỗi tuần" } ?? ""),
                           Text(f.bpmPerWeek == nil ? "cần ít nhất 3 ngày đạt trên 90% trong 1 tuần để thấy xu hướng" : "tăng chậm dần theo thời gian").foregroundStyle(.secondary))
                }
                ForEach([(1.0, "1 tháng tới"), (3, "3 tháng tới"), (6, "Nửa năm tới"), (12, "1 năm tới")], id: \.0) { months, label in
                    HStack(alignment: .firstTextBaseline) {
                        Text(label).frame(width: 110, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gradeText(f.position(afterMonths: months)))
                            Text(detail(f, months)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let tip = compare(f) { Text(tip).font(.callout) }
            }
        }
    }

    private func minutesChart(_ e: ForecastEvidence) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days = (0..<e.windowDays).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        let perDay = Dictionary(grouping: sessions.filter { $0.date >= (days.first ?? today) }) { cal.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.seconds / 60 } }
        return Chart {
            ForEach(days, id: \.self) { d in
                BarMark(x: .value("Ngày", d, unit: .day), y: .value("Phút", perDay[d] ?? 0)).foregroundStyle(Theme.shell)
            }
            RuleMark(y: .value("Trung bình", e.forecast.minutesPerDay))
                .foregroundStyle(Theme.offTime).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartYAxisLabel("phút")
        .frame(height: 110)
    }

    private func factor(_ title: String, _ value: String, _ note: Text) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                note.font(.footnote)
            }
        }
    }

    // MARK: Helpers

    private func makeEvidence() -> ForecastEvidence {
        var best: [String: Double] = [:]
        for a in attempts { if let id = a.levelTestId { best[id] = max(best[id] ?? 0, a.score) } }
        let levels = BookLibrary.levels
        return ForecastEvidence(records: HistoryStore.records(context), levelReached: SettingsStore.levelHistory,
                                progress: LevelProgress(bestScores: best, levels: levels), levels: levels,
                                windowDays: windowDays, now: Date(), calendar: .current)
    }

    private func effect(_ x: Double, faster: String, slower: String) -> Text {
        let pct = Int((abs(1 - x) * 100).rounded())
        if x < 0.98 { return Text(String(format: faster, pct)).foregroundStyle(Theme.onTime) }
        if x > 1.02 { return Text(String(format: slower, pct)).foregroundStyle(Theme.missed) }
        return Text("như mức trung bình").foregroundStyle(.secondary)
    }

    private func gradeText(_ g: Double) -> String {
        if g >= 8 { return "Grade 8" }
        let whole = Int(g), frac = Int(((g - Double(whole)) * 100).rounded())
        let name = whole == 0 ? "Chưa có Grade" : "Grade \(whole)"
        return frac >= 5 ? "\(name) (đang \(frac)% tới Grade \(whole + 1))" : name
    }

    private func detail(_ f: ProgressForecast, _ months: Double) -> String {
        let hours = Int((f.minutesPerDay * 30.44 * months / 60).rounded())
        return f.bpm(afterMonths: months).map { "Tempo khoảng \($0) BPM, thêm \(hours) giờ tập" } ?? "Thêm \(hours) giờ tập"
    }

    private func compare(_ f: ProgressForecast) -> String? {
        var tips: [String] = []
        let now6 = f.position(afterMonths: 6)
        if Double(budgetMinutes) > f.minutesPerDay + 5 {
            let more = f.with(minutesPerDay: Double(budgetMinutes)).position(afterMonths: 6)
            tips.append("Nếu tập \(budgetMinutes >= 60 ? "\(budgetMinutes / 60) tiếng" : "\(budgetMinutes) phút") mỗi ngày như mức đã chọn: sau nửa năm khoảng \(gradeText(more)), thay vì \(gradeText(now6)).")
        }
        if let s = f.recentAverageScore, s < 90 {
            let clean = ProgressForecast(minutesPerDay: f.minutesPerDay, currentGrade: f.currentGrade, testsPassed: f.testsPassed,
                                         testsInNextGrade: f.testsInNextGrade, pastGrades: f.pastGrades, recentAverageScore: 90,
                                         currentBpm: f.currentBpm, bpmPerWeek: f.bpmPerWeek)
            tips.append("Nếu giữ thời gian như cũ nhưng tập chậm lại cho sạch (trên 90%): sau nửa năm khoảng \(gradeText(clean.position(afterMonths: 6))).")
        }
        return tips.isEmpty ? nil : tips.joined(separator: "\n")
    }

    private func span(_ months: Double?) -> String {
        guard let m = months else { return "–" }
        if m == 0 { return "0" }
        if m < 1 { return "<1" }
        return "\(max(1, Int((m * 0.85).rounded(.down))))–\(Int((m * 1.15).rounded(.up)))"
    }

    private func oneDecimal(_ x: Double) -> String { x.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "vi_VN"))) }
}

/// The day's blocks as one bar, widths in proportion to minutes.
private struct BlockBar: View {
    let blocks: [DailyBudget.Block]
    private let tints: [Color] = [Theme.shell, Theme.onTime, Theme.offTime, .gray]
    var body: some View {
        GeometryReader { geo in
            let total = Double(blocks.reduce(0) { $0 + $1.minutes })
            HStack(spacing: 3) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { i, b in
                    Text("\(b.minutes)′").font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .frame(width: max(0, (geo.size.width - 3 * Double(blocks.count - 1)) * Double(b.minutes) / total), height: 28)
                        .background(tints[i % tints.count].opacity(0.4 + 0.6 * (1 - Double(i) / Double(blocks.count))))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(blocks.map { "\($0.title) \($0.minutes) phút" }.joined(separator: ", "))
    }
}
