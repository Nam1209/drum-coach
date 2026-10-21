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
    /// Pad, kit or both: today's exercises are chosen to fit.
    @AppStorage("practiceInstrument") private var instrumentRaw = PracticeInstrument.both.rawValue
    private var instrument: PracticeInstrument { PracticeInstrument(rawValue: instrumentRaw) ?? .both }
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let catalog = ExerciseCatalog.all(context)
        let base = todayPlan
        let plan = (day: base.day.adapted(to: instrument, catalog: catalog), source: base.source)
        let total = plan.day.allItems.reduce(0) { $0 + $1.minutes }
        let rank = PracticeRank.for(points: HistoryStore.totalPoints(context), grade: SettingsStore.currentGrade)
        let streak = ProgressSummary(records: HistoryStore.records(context), now: Date(), calendar: .current).streakDays
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(title: L("Hôm nay", "Today"), subtitle: Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.current)))
                HStack(alignment: .bottom, spacing: 40) {
                    Readout(value: "\(total)", caption: L("phút tập hôm nay", "minutes planned today"), size: 64)
                    Readout(value: "\(streak)", caption: L("ngày liên tiếp", "day streak"), size: 40)
                    Readout(value: "\(rank.level)", caption: L("level: \(rank.title)", "level: \(rank.title)"), size: 40, tint: Theme.shell)
                    Spacer()
                    sessionControl(plan.day)
                }
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(L("Hôm nay tập trên", "Today I practise on")).font(.headline)
                    Picker(L("Dụng cụ", "Instrument"), selection: $instrumentRaw) {
                        Text("Pad").tag(PracticeInstrument.pad.rawValue)
                        Text(L("Trống", "Kit")).tag(PracticeInstrument.kit.rawValue)
                        Text(L("Cả hai", "Both")).tag(PracticeInstrument.both.rawValue)
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 320)
                    .disabled(runner != nil)
                    Spacer()
                }
                Text(instrumentHint).font(.callout).foregroundStyle(.secondary)
                if instrument != .pad { DrumStatusPill() }
                Text(plan.source).font(.callout).foregroundStyle(.secondary)
                if finished { journal }
                part(L("Khởi động", "Warm-up"), plan.day.warmup, catalog, segment: 0)
                part(L("Bài chính", "Main"), plan.day.main, catalog, segment: 1)
                part(L("Bài vui", "Fun"), plan.day.fun, catalog, segment: 2)
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
        .task { if await ReminderScheduler.isAuthorized() { scheduleReminders() } }
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
                Button(L("Bỏ qua", "Skip")) { self.runner?.skip() }.buttonStyle(.bordered)
                PlayButton(isPlaying: true, size: 64) { self.runner = nil }
            }
        } else {
            HStack(spacing: 14) {
                Text(finished ? L("Xong buổi tập", "Session done") : L("Bắt đầu buổi tập", "Start session")).font(.headline)
                PlayButton(isPlaying: false, size: 64) { start(day) }
            }
        }
    }

    private var journal: some View {
        Stage {
            VStack(alignment: .leading, spacing: 10) {
                Label(L("Xong buổi tập hôm nay", "Today's session done"), systemImage: "checkmark.seal.fill").foregroundStyle(Theme.onTime).font(.headline)
                TextField(L("Ghi lại cảm nhận, chỗ khó", "Note how it felt, what was hard"), text: $note, axis: .vertical)
                Button(L("Lưu vào nhật ký", "Save to journal")) { saveNote() }.disabled(note.isEmpty)
            }
        }
    }

    private func part(_ title: String, _ items: [PlannedItem], _ catalog: [String: Exercise], segment: Int) -> some View {
        let active = runner?.currentIndex == segment
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(active ? Theme.shell : .primary)
                Spacer()
                Text(L("\(items.reduce(0) { $0 + $1.minutes }) phút", "\(items.reduce(0) { $0 + $1.minutes }) min")).font(Theme.number(15, weight: .medium)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                if items.isEmpty { Text(L("Không có bài", "No exercises")).foregroundStyle(.secondary).padding(16).frame(maxWidth: .infinity, alignment: .leading) }
                ForEach(Array(items.enumerated()), id: \.offset) { k, item in
                    if let ex = exercise(item, catalog) {
                        let surface = DayPlan.surface(forSegment: segment, on: instrument)
                        NavigationLink {
                            PracticeView(exercises: [ex], voiceBank: voiceBank, bpm: Double(item.bpm), mode: surface == .pad ? .pad : .eDrum)
                        } label: {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ExerciseTitle.short(ex.title)).foregroundStyle(.primary)
                                    Text(item.focus).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(surface == .pad ? "Pad" : L("Trống", "Kit"))
                                    .font(.caption.weight(.semibold)).foregroundStyle(surface == .pad ? Theme.shell : .secondary)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(surface == .pad ? Theme.shell.opacity(0.12) : Theme.hairline))
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

    private var instrumentHint: String {
        switch instrument {
        case .pad: L("Chỉ dùng tay trên một mặt: bài cần cả bộ trống được đổi thành phần tay trên pad.", "Hands on one surface: exercises that need the kit become their hand part on the pad.")
        case .kit: L("Tập trên trống điện: groove, tom và phần chân đều được chấm.", "On the e-kit: grooves, toms and feet are all scored.")
        case .both: L("Khởi động trên pad, bài chính và bài vui trên trống.", "Warm up on the pad, then the main and fun parts on the kit.")
        }
    }

    private func exercise(_ item: PlannedItem, _ catalog: [String: Exercise]) -> Exercise? {
        if let id = item.exerciseId, let e = catalog[id] { return e }
        return item.newExerciseDSL.flatMap { try? ExerciseDSL.parse($0) }
    }

    /// Day of the active plan (1–7, counting from when it was applied) or a default for the current level.
    private var todayPlan: (day: DayPlan, source: String) {
        if let active = StoredReport.active(in: reports), let r = active.report, !r.weekPlan.isEmpty, let applied = active.appliedAt {
            let n = (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: applied), to: Calendar.current.startOfDay(for: Date())).day ?? 0) % 7 + 1
            if let d = r.weekPlan.first(where: { $0.day == n }) ?? r.weekPlan.first { return (d, L("Theo \(active.title) · ngày \(d.day)", "From \(active.title) · day \(d.day)")) }
        }
        return (defaultPlan, L("Kế hoạch mặc định (chưa có kế hoạch của thầy)", "Default plan (no teacher plan yet)"))
    }

    private var defaultPlan: DayPlan {
        let levels = BookLibrary.levels
        let level = levels.first { $0.id == min(8, SettingsStore.currentGrade + 1) } ?? levels[0]
        let warm = PlannedItem(exerciseId: "start-1", newExerciseDSL: nil, bpm: 60, minutes: 5, focus: L("Khởi động, thả lỏng", "Warm up, loosen up"))
        let main = level.tests.prefix(2).map { PlannedItem(exerciseId: $0.id, newExerciseDSL: nil, bpm: Int($0.bpm) - 6, minutes: 10, focus: $0.skill) }
        // On a pad-only day the fun part is a rudiment rather than a groove squeezed onto one surface.
        let fun = instrument == .pad
            ? PlannedItem(exerciseId: "start-3", newExerciseDSL: nil, bpm: 70, minutes: 5, focus: L("Paradiddle cho vui, nhấn rõ", "A paradiddle for fun, clear accents"))
            : PlannedItem(exerciseId: "start-4", newExerciseDSL: nil, bpm: 80, minutes: 5, focus: L("Groove cho vui", "A groove for fun"))
        return DayPlan(day: 1, warmup: [warm], main: Array(main), fun: [fun])
    }

    private func start(_ day: DayPlan) {
        finished = false
        // Ask for reminders when practice starts: the prompt then has an obvious reason.
        Task { if await ReminderScheduler.requestPermission() { scheduleReminders() } }
        runner = SessionRunner(segments: [(L("Khởi động", "Warm-up"), day.warmup), (L("Bài chính", "Main"), day.main), (L("Bài vui", "Fun"), day.fun)].map {
            SessionRunner.Segment(title: $0.0, minutes: Double($0.1.reduce(0) { $0 + $1.minutes }))
        })
    }

    private func saveNote() {
        context.insert(JournalEntry(text: note))
        try? context.save()
        note = ""
    }

    private func scheduleReminders() {
        reschedule()
        if let d = ReminderScheduler.installDate { ReminderScheduler.scheduleReinstallReminder(installDate: d) }
    }

    private func reschedule() {
        let practicedToday = sessions.first.map { Calendar.current.isDateInToday($0.date) } ?? false
        ReminderScheduler.schedule(today: todayPlan.day.adapted(to: instrument, catalog: ExerciseCatalog.all(context)), practicedToday: practicedToday || finished)
    }
}
