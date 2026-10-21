import DrumAI
import DrumAnalysis
import DrumAudio
import DrumCore
import DrumLibrary
import SwiftData
import SwiftUI

/// Home screen: today's structured session from the teacher's plan (or a default plan for the current level).
struct TodayView: View {
    let voiceBank: CountVoiceBank
    @Environment(\.modelContext) private var context
    @Query(sort: \StoredReport.created, order: .reverse) private var reports: [StoredReport]
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @State private var runner: SessionRunner?
    @State private var note = ""
    @State private var finished = false
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let plan = todayPlan
        let catalog = ExerciseCatalog.all(context)
        let total = plan.day.allItems.reduce(0) { $0 + $1.minutes }
        let streak = ProgressSummary(records: HistoryStore.records(context), now: Date(), calendar: .current).streakDays
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(title: "Hôm nay", subtitle: Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "vi_VN"))))
                HStack(alignment: .bottom, spacing: 40) {
                    Readout(value: "\(total)", caption: "phút tập hôm nay", size: 64)
                    Readout(value: "\(streak)", caption: streak == 1 ? "ngày liên tiếp" : "ngày liên tiếp", size: 40)
                    Readout(value: "\(SettingsStore.currentGrade)", caption: "cấp độ hiện tại", size: 40)
                    Spacer()
                    sessionControl(plan.day)
                }
                Text(plan.source).font(.callout).foregroundStyle(.secondary)
                if finished { journal }
                part("Khởi động", plan.day.warmup, catalog, segment: 0)
                part("Bài chính", plan.day.main, catalog, segment: 1)
                part("Bài vui", plan.day.fun, catalog, segment: 2)
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.canvas)
        .onReceive(clock) { _ in
            guard var r = runner else { return }
            _ = r.tick(1)
            runner = r
            if r.isFinished { runner = nil; finished = true; reschedule() }
        }
        .task {
            if await ReminderScheduler.requestPermission() {
                reschedule()
                if let d = ReminderScheduler.installDate { ReminderScheduler.scheduleReinstallReminder(installDate: d) }
            }
        }
    }

    /// Big countdown + start/skip for the structured session.
    @ViewBuilder
    private func sessionControl(_ day: DayPlan) -> some View {
        if let runner, let seg = runner.current {
            HStack(spacing: 18) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%d:%02d", Int(runner.remaining) / 60, Int(runner.remaining) % 60)).font(Theme.number(44))
                    Text(seg.title).font(.footnote).foregroundStyle(.secondary)
                }
                Button("Bỏ qua") { self.runner?.skip() }.buttonStyle(.bordered)
                PlayButton(isPlaying: true, size: 64) { self.runner = nil }
            }
        } else {
            HStack(spacing: 14) {
                Text(finished ? "Xong buổi tập" : "Bắt đầu buổi tập").font(.headline)
                PlayButton(isPlaying: false, size: 64) { start(day) }
            }
        }
    }

    private var journal: some View {
        Stage {
            VStack(alignment: .leading, spacing: 10) {
                Label("Xong buổi tập hôm nay", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.onTime).font(.headline)
                TextField("Ghi lại cảm nhận, chỗ khó", text: $note, axis: .vertical)
                Button("Lưu vào nhật ký") { saveNote() }.disabled(note.isEmpty)
            }
        }
    }

    private func part(_ title: String, _ items: [PlannedItem], _ catalog: [String: Exercise], segment: Int) -> some View {
        let active = runner?.currentIndex == segment
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(active ? Theme.shell : .primary)
                Spacer()
                Text("\(items.reduce(0) { $0 + $1.minutes }) phút").font(Theme.number(15, weight: .medium)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                if items.isEmpty { Text("Không có bài").foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading) }
                ForEach(Array(items.enumerated()), id: \.offset) { k, item in
                    if let ex = exercise(item, catalog) {
                        NavigationLink {
                            PracticeView(exercises: [ex], voiceBank: voiceBank, bpm: Double(item.bpm))
                        } label: {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ex.title).foregroundStyle(.primary)
                                    Text(item.focus).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(item.bpm)").font(Theme.number(20)).foregroundStyle(.primary)
                                Text("BPM").font(.caption).foregroundStyle(.secondary)
                                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if k < items.count - 1 { Divider().padding(.leading, 18) }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.stage))
        }
    }

    private func exercise(_ item: PlannedItem, _ catalog: [String: Exercise]) -> Exercise? {
        if let id = item.exerciseId, let e = catalog[id] { return e }
        return item.newExerciseDSL.flatMap { try? ExerciseDSL.parse($0) }
    }

    /// Day of the active plan (1–7, counting from when it was applied) or a default for the current level.
    private var todayPlan: (day: DayPlan, source: String) {
        if let active = reports.first(where: { $0.appliedAt != nil }), let r = active.report, !r.weekPlan.isEmpty, let applied = active.appliedAt {
            let n = (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: applied), to: Calendar.current.startOfDay(for: Date())).day ?? 0) % 7 + 1
            if let d = r.weekPlan.first(where: { $0.day == n }) ?? r.weekPlan.first { return (d, "Theo \(active.title) · ngày \(d.day)") }
        }
        return (defaultPlan, "Kế hoạch mặc định (chưa có kế hoạch của thầy)")
    }

    private var defaultPlan: DayPlan {
        let levels = BookLibrary.levels
        let level = levels.first { $0.id == min(8, SettingsStore.currentGrade + 1) } ?? levels[0]
        let warm = PlannedItem(exerciseId: "start-1", newExerciseDSL: nil, bpm: 60, minutes: 5, focus: "Khởi động, thả lỏng")
        let main = level.tests.prefix(2).map { PlannedItem(exerciseId: $0.id, newExerciseDSL: nil, bpm: Int($0.bpm) - 6, minutes: 10, focus: $0.skill) }
        let fun = PlannedItem(exerciseId: "start-4", newExerciseDSL: nil, bpm: 80, minutes: 5, focus: "Groove cho vui")
        return DayPlan(day: 1, warmup: [warm], main: Array(main), fun: [fun])
    }

    private func start(_ day: DayPlan) {
        finished = false
        runner = SessionRunner(segments: [("Khởi động", day.warmup), ("Bài chính", day.main), ("Bài vui", day.fun)].map {
            SessionRunner.Segment(title: $0.0, minutes: Double($0.1.reduce(0) { $0 + $1.minutes }))
        })
    }

    private func saveNote() {
        context.insert(JournalEntry(text: note))
        try? context.save()
        note = ""
    }

    private func reschedule() {
        let practicedToday = sessions.first.map { Calendar.current.isDateInToday($0.date) } ?? false
        ReminderScheduler.schedule(today: todayPlan.day, practicedToday: practicedToday || finished)
    }
}
