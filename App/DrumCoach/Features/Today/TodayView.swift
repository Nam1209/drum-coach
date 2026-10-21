import DrumAI
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
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Date().formatted(date: .complete, time: .omitted)).foregroundStyle(.secondary)
                    Text(plan.source).font(.headline)
                    Text("\(plan.day.allItems.reduce(0) { $0 + $1.minutes }) phút · Level hiện tại: \(SettingsStore.currentGrade)")
                        .foregroundStyle(.secondary)
                }
                if let runner, let seg = runner.current {
                    VStack(alignment: .leading) {
                        Text("Đang tập: \(seg.title)").font(.title3.bold())
                        ProgressView(value: seg.minutes * 60 - runner.remaining, total: seg.minutes * 60)
                        Text("Còn \(Int(runner.remaining) / 60):\(String(format: "%02d", Int(runner.remaining) % 60))").monospacedDigit()
                    }
                    Button("Bỏ qua phần này") { self.runner?.skip() }
                } else if finished {
                    Label("Xong buổi tập hôm nay! 🎉", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    TextField("Nhật ký: cảm nhận, chỗ khó…", text: $note, axis: .vertical)
                    Button("Lưu nhật ký") { saveNote() }.disabled(note.isEmpty)
                } else {
                    Button("Bắt đầu buổi tập") { start(plan.day) }.buttonStyle(.borderedProminent)
                }
            }
            part("Khởi động", plan.day.warmup, catalog)
            part("Bài chính", plan.day.main, catalog)
            part("Bài vui", plan.day.fun, catalog)
        }
        .navigationTitle("Hôm nay tập gì")
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

    private func part(_ title: String, _ items: [PlannedItem], _ catalog: [String: Exercise]) -> some View {
        Section(title) {
            if items.isEmpty { Text("–").foregroundStyle(.secondary) }
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                if let ex = exercise(item, catalog) {
                    NavigationLink {
                        PracticeView(exercises: [ex], voiceBank: voiceBank, bpm: Double(item.bpm))
                            .navigationTitle(ex.title).navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(ex.title)
                            Text("\(item.bpm) BPM · \(item.minutes) phút · \(item.focus)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
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
        let level = LevelCatalog.levels.first { $0.id == min(8, SettingsStore.currentGrade + 1) } ?? LevelCatalog.levels[0]
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
