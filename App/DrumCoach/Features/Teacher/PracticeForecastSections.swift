import Charts
import DrumAI
import DrumAnalysis
import DrumCore
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
        CardSection(L("Tập bao lâu mỗi ngày?", "How long to practice each day?"),
                    footer: L("Số tháng tính theo tốc độ học, điểm và số bài đã đạt của chính bạn. Đây là ước tính, không phải cam kết.", "Months are based on your own learning pace, scores and exercises passed. This is an estimate, not a promise.")) {
            Picker(L("Thời lượng", "Duration"), selection: $budgetMinutes) {
                Text(L("30 phút", "30 min")).tag(30); Text(L("1 tiếng", "1 hour")).tag(60); Text(L("2 tiếng", "2 hours")).tag(120); Text(L("4 tiếng", "4 hours")).tag(240)
            }
            .pickerStyle(.segmented)
            ForEach(Array(plan.sessions.enumerated()), id: \.offset) { k, blocks in
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.sessions.count > 1 ? L("Buổi \(k + 1), \(blocks.reduce(0) { $0 + $1.minutes }) phút", "Session \(k + 1), \(blocks.reduce(0) { $0 + $1.minutes }) min") : L("\(blocks.reduce(0) { $0 + $1.minutes }) phút", "\(blocks.reduce(0) { $0 + $1.minutes }) min"))
                        .font(.footnote).foregroundStyle(.secondary)
                    BlockBar(blocks: blocks)
                    ForEach(blocks, id: \.self) { b in
                        (Text(b.title).bold() + Text(L(" \(b.minutes) phút  ", " \(b.minutes) min  ")) + Text(b.detail).foregroundStyle(.secondary)).font(.callout)
                    }
                    if k < plan.sessions.count - 1 { Text(L("Nghỉ \(plan.breakMinutes) phút", "Break \(plan.breakMinutes) min")).font(.footnote).foregroundStyle(.secondary) }
                }
                .padding(.vertical, 4)
            }
            let f = e.forecast.with(minutesPerDay: Double(budgetMinutes))
            HStack(alignment: .bottom, spacing: 32) {
                if e.forecast.currentGrade < 8 {
                    Readout(value: span(f.months(toReach: e.forecast.currentGrade + 1)), caption: L("tháng lên Grade \(e.forecast.currentGrade + 1)", "months to Grade \(e.forecast.currentGrade + 1)"), size: 34)
                }
                Readout(value: span(f.months(toReach: 8)), caption: L("tháng tới Grade 8", "months to Grade 8"), size: 34)
                Readout(value: "\(plan.restDaysPerWeek)", caption: L("ngày nghỉ mỗi tuần", "rest days per week"), size: 34)
            }
            ForEach(plan.warnings, id: \.self) { Text($0).font(.callout).foregroundStyle(budgetMinutes == 240 ? Theme.offTime : .secondary) }
            Button(applied ? L("Đã đặt cho kế hoạch tuần tới", "Set for next week's plan") : L("Dùng mức này cho kế hoạch", "Use this for the plan")) {
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
        CardSection(L("Dự đoán cho riêng bạn", "Your personal forecast"),
                    footer: L("Dựa trên thời gian tập, số bài đã đạt, tốc độ lên các Grade trước, điểm trung bình và tempo của bạn. Càng tập lâu với app, dự đoán càng sát.", "Based on your practice time, exercises passed, how fast you moved through earlier Grades, average score and tempo. The longer you use the app, the closer the forecast.")) {
            Picker(L("Khoảng thời gian", "Time range"), selection: $windowDays) { Text(L("7 ngày qua", "Last 7 days")).tag(7); Text(L("30 ngày qua", "Last 30 days")).tag(30) }
                .pickerStyle(.segmented)
            if sessions.isEmpty {
                Text(L("Chưa có buổi tập nào. Tập vài buổi để app có dữ liệu dự đoán cho riêng bạn.", "No sessions yet. Practice a few times so the app has data to forecast for you.")).foregroundStyle(.secondary)
            } else {
                minutesChart(e)
                let f = e.forecast
                factor(L("Thời gian", "Time"), L("\(Int(f.minutesPerDay.rounded())) phút/ngày, tập \(e.daysPracticed)/\(e.windowDays) ngày", "\(Int(f.minutesPerDay.rounded())) min/day, practiced \(e.daysPracticed)/\(e.windowDays) days"),
                       Text(ProgressForecast.typicalMonthsPerGrade(minutes: f.minutesPerDay).isFinite
                            ? L("thường mất \(oneDecimal(ProgressForecast.typicalMonthsPerGrade(minutes: f.minutesPerDay))) tháng mỗi Grade", "usually takes \(oneDecimal(ProgressForecast.typicalMonthsPerGrade(minutes: f.minutesPerDay))) months per Grade")
                            : L("chưa tập trong \(e.windowDays) ngày qua nên chưa dự đoán được", "no practice in the last \(e.windowDays) days, so no forecast yet")).foregroundStyle(.secondary))
                if f.testsInNextGrade > 0 {
                    factor(L("Đã hoàn thành", "Completed"), L("\(f.testsPassed)/\(f.testsInNextGrade) bài kiểm tra Grade \(f.currentGrade + 1)", "\(f.testsPassed)/\(f.testsInNextGrade) Grade \(f.currentGrade + 1) tests"),
                           Text(L("bắt đầu từ \(oneDecimal(f.position(afterMonths: 0)))", "starting from \(oneDecimal(f.position(afterMonths: 0)))")).foregroundStyle(.secondary))
                }
                factor(L("Tốc độ học", "Learning pace"), f.pastGrades.isEmpty ? L("Chưa lên Grade nào trong app", "No Grade reached in the app yet") : f.pastGrades.map { L("Grade \($0.grade) mất \(oneDecimal($0.months)) tháng", "Grade \($0.grade) took \(oneDecimal($0.months)) months") }.joined(separator: ", "),
                       effect(f.paceFactor, faster: L("nhanh hơn %d%% so với người tập cùng thời gian", "%d%% faster than others with the same practice time"), slower: L("chậm hơn %d%% so với người tập cùng thời gian", "%d%% slower than others with the same practice time")))
                if let s = f.recentAverageScore {
                    factor(L("Chất lượng", "Quality"), L("điểm trung bình \(Int(s.rounded()))%", "average score \(Int(s.rounded()))%"),
                           effect(f.qualityFactor, faster: L("tập sạch, nhanh hơn %d%%", "clean playing, %d%% faster"), slower: s < 60 ? L("dưới 60% nhiều, chậm hơn %d%%", "well under 60%%, %d%% slower") : L("còn ẩu, chậm hơn %d%%", "still sloppy, %d%% slower")))
                }
                if let bpm = f.currentBpm {
                    factor("Tempo", "\(e.trackedTitle ?? L("Bài chính", "Main exercise")) \(Int(bpm)) BPM" + (f.bpmPerWeek.map { L(", tăng \(oneDecimal($0)) BPM mỗi tuần", ", up \(oneDecimal($0)) BPM per week") } ?? ""),
                           Text(f.bpmPerWeek == nil ? L("cần ít nhất 3 ngày đạt trên 90% trong 1 tuần để thấy xu hướng", "needs at least 3 days above 90% in a week to show a trend") : L("tăng chậm dần theo thời gian", "slows down over time")).foregroundStyle(.secondary))
                }
                ForEach([(1.0, L("1 tháng tới", "Next month")), (3, L("3 tháng tới", "Next 3 months")), (6, L("Nửa năm tới", "Next 6 months")), (12, L("1 năm tới", "Next year"))], id: \.0) { months, label in
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
                BarMark(x: .value(L("Ngày", "Day"), d, unit: .day), y: .value(L("Phút", "Minutes"), perDay[d] ?? 0)).foregroundStyle(Theme.shell)
            }
            RuleMark(y: .value(L("Trung bình", "Average"), e.forecast.minutesPerDay))
                .foregroundStyle(Theme.offTime).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartYAxisLabel(L("phút", "min"))
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
                                progress: LevelProgress(bestScores: best, levels: levels, reached: SettingsStore.levelHistory.map(\.0).max() ?? 0), levels: levels,
                                windowDays: windowDays, now: Date(), calendar: .current)
    }

    private func effect(_ x: Double, faster: String, slower: String) -> Text {
        let pct = Int((abs(1 - x) * 100).rounded())
        if x < 0.98 { return Text(String(format: faster, pct)).foregroundStyle(Theme.onTime) }
        if x > 1.02 { return Text(String(format: slower, pct)).foregroundStyle(Theme.missed) }
        return Text(L("như mức trung bình", "about average")).foregroundStyle(.secondary)
    }

    private func gradeText(_ g: Double) -> String {
        if g >= 8 { return "Grade 8" }
        let whole = Int(g), frac = Int(((g - Double(whole)) * 100).rounded())
        let name = whole == 0 ? L("Chưa có Grade", "No Grade yet") : "Grade \(whole)"
        return frac >= 5 ? L("\(name) (đang \(frac)% tới Grade \(whole + 1))", "\(name) (\(frac)% of the way to Grade \(whole + 1))") : name
    }

    private func detail(_ f: ProgressForecast, _ months: Double) -> String {
        let hours = Int((f.minutesPerDay * 30.44 * months / 60).rounded())
        return f.bpm(afterMonths: months).map { L("Tempo khoảng \($0) BPM, thêm \(hours) giờ tập", "Tempo around \($0) BPM, \(hours) more hours of practice") } ?? L("Thêm \(hours) giờ tập", "\(hours) more hours of practice")
    }

    private func compare(_ f: ProgressForecast) -> String? {
        var tips: [String] = []
        let now6 = f.position(afterMonths: 6)
        if Double(budgetMinutes) > f.minutesPerDay + 5 {
            let more = f.with(minutesPerDay: Double(budgetMinutes)).position(afterMonths: 6)
            let amount = budgetMinutes >= 60 ? L("\(budgetMinutes / 60) tiếng", "\(budgetMinutes / 60) h") : L("\(budgetMinutes) phút", "\(budgetMinutes) min")
            tips.append(L("Nếu tập \(amount) mỗi ngày như mức đã chọn: sau nửa năm khoảng \(gradeText(more)), thay vì \(gradeText(now6)).", "If you practice \(amount) a day as selected: about \(gradeText(more)) in six months, instead of \(gradeText(now6))."))
        }
        if let s = f.recentAverageScore, s < 90 {
            let clean = ProgressForecast(minutesPerDay: f.minutesPerDay, currentGrade: f.currentGrade, testsPassed: f.testsPassed,
                                         testsInNextGrade: f.testsInNextGrade, pastGrades: f.pastGrades, recentAverageScore: 90,
                                         currentBpm: f.currentBpm, bpmPerWeek: f.bpmPerWeek)
            tips.append(L("Nếu giữ thời gian như cũ nhưng tập chậm lại cho sạch (trên 90%): sau nửa năm khoảng \(gradeText(clean.position(afterMonths: 6))).", "If you keep the same time but slow down to play clean (above 90%): about \(gradeText(clean.position(afterMonths: 6))) in six months."))
        }
        return tips.isEmpty ? nil : tips.joined(separator: "\n")
    }

    private func span(_ months: Double?) -> String {
        guard let m = months else { return "–" }
        if m == 0 { return "0" }
        if m < 1 { return "<1" }
        return "\(max(1, Int((m * 0.85).rounded(.down))))–\(Int((m * 1.15).rounded(.up)))"
    }

    private func oneDecimal(_ x: Double) -> String { x.formatted(.number.precision(.fractionLength(0...1)).locale(AppLocale.current)) }
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
        .accessibilityLabel(blocks.map { L("\($0.title) \($0.minutes) phút", "\($0.title) \($0.minutes) min") }.joined(separator: ", "))
    }
}
