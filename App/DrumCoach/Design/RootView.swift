import DrumAudio
import DrumCore
import DrumLibrary
import SwiftUI

/// iPad sidebar navigation, grouped by what you're doing.
struct RootView: View {
    let voiceBank: CountVoiceBank

    enum Destination: String, Hashable, CaseIterable, Identifiable {
        case today, practice, metronome, counting, lessons, library, levels, teacher, progress, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .today: "Hôm nay"
            case .practice: "Tập"
            case .metronome: "Máy nhịp"
            case .counting: "Đếm nhịp"
            case .lessons: "Bài học"
            case .library: "Thư viện"
            case .levels: "Cấp độ"
            case .teacher: "Thầy AI"
            case .progress: "Tiến độ"
            case .settings: "Cài đặt"
            }
        }
        var icon: String {
            switch self {
            case .today: "sun.max"
            case .practice: "music.quarternote.3"
            case .metronome: "metronome"
            case .counting: "waveform"
            case .lessons: "graduationcap"
            case .library: "books.vertical"
            case .levels: "chart.bar.xaxis.ascending"
            case .teacher: "person.wave.2"
            case .progress: "chart.line.uptrend.xyaxis"
            case .settings: "gearshape"
            }
        }
    }

    private let groups: [(String?, [Destination])] = [
        (nil, [.today]),
        ("Luyện tập", [.practice, .metronome, .counting]),
        ("Học", [.lessons, .library, .levels]),
        ("Đồng hành", [.teacher, .progress]),
        (nil, [.settings]),
    ]

    @State private var selection: Destination? = {
        #if DEBUG
        // `-screen practice` opens a screen directly (used for screenshots during development).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-screen"), i + 1 < args.count { return Destination(rawValue: args[i + 1]) ?? .today }
        #endif
        return .today
    }()
    @State private var columns: NavigationSplitViewVisibility = .automatic
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $selection) {
                ForEach(groups.indices, id: \.self) { i in
                    Section {
                        ForEach(groups[i].1) { d in Label(d.title, systemImage: d.icon).tag(d) }
                    } header: {
                        if let h = groups[i].0 { Text(h) }
                    }
                }
            }
            .navigationTitle("DrumCoach")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack { detail(selection ?? .today) }
                .id(selection)
        }
        .tint(Theme.shell)
        #if DEBUG
        .task { DemoData.seedIfRequested(context) }
        #endif
    }

    @ViewBuilder
    private func detail(_ d: Destination) -> some View {
        switch d {
        case .today: TodayView(voiceBank: voiceBank)
        case .practice:
            #if DEBUG
            // `-exercise G3-A` opens a level test directly (screenshots of long pieces).
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-exercise"), i + 1 < ProcessInfo.processInfo.arguments.count,
               let item = BookLibrary.levels.flatMap(\.tests).first(where: { $0.id == ProcessInfo.processInfo.arguments[i + 1] }),
               let ex = try? ExerciseDSL.parse(item.dsl) {
                PracticeView(exercises: [ex], voiceBank: voiceBank)
            } else {
                PracticeView(exercises: StarterExercises.all, voiceBank: voiceBank)
            }
            #else
            PracticeView(exercises: StarterExercises.all, voiceBank: voiceBank)
            #endif
        case .metronome: MetronomeView(voiceBank: voiceBank)
        case .counting: CountCoachView(voiceBank: voiceBank)
        case .lessons: LessonsView(voiceBank: voiceBank)
        case .library: LibraryView(voiceBank: voiceBank)
        case .levels: LevelListView(voiceBank: voiceBank)
        case .teacher: TeacherView()
        case .progress: ProgressHubView()
        case .settings: SettingsView(voiceBank: voiceBank)
        }
    }
}

/// Progress: charts, journey and history in one place.
struct ProgressHubView: View {
    @State private var tab = 0
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Biểu đồ").tag(0); Text("Hành trình").tag(1); Text("Lịch sử").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.pagePadding).padding(.vertical, 12)
            switch tab {
            case 0: ProgressChartsView()
            case 1: JourneyView()
            default: HistoryView()
            }
        }
        .navigationTitle("Tiến độ")
        .background(Theme.canvas)
    }
}
