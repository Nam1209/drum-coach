import AVKit
import DrumAI
import DrumCore
import SwiftUI

/// See yourself while practising, record a take, compare with the checklist, ask the teacher.
struct PostureCameraView: View {
    let exerciseTitle: String
    @StateObject private var recorder = PracticeRecorder()
    @AppStorage("claude.model") private var model = ClaudeClient.defaultModel
    @AppStorage("starredVideos") private var starredRaw = ""
    @State private var allowed = true
    @State private var frames: [Data] = []
    @State private var checked: Set<String> = []
    @State private var review: PostureCheck.Review?
    @State private var working = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if allowed {
                        CameraPreview(session: recorder.session).frame(height: 360).clipShape(RoundedRectangle(cornerRadius: 12))
                        Button(recorder.isRecording ? L("⏹ Dừng ghi", "⏹ Stop recording") : L("⏺ Ghi lại lần tập", "⏺ Record a take")) { recorder.toggleRecording() }
                    } else {
                        Text(L("Cần quyền dùng camera trong Cài đặt iPad.", "Camera access is needed. Turn it on in iPad Settings.")).foregroundStyle(.red)
                    }
                } footer: {
                    Text(L("Đặt iPad sao cho thấy cả hai tay và vai. Video chỉ lưu trên máy, tự xóa sau 30 ngày trừ khi gắn sao.", "Place the iPad so both hands and your shoulders are visible. Video stays on this device and is deleted after 30 days unless starred."))
                }
                if let video = recorder.lastVideo {
                    Section(L("Lần ghi vừa rồi", "Latest take")) {
                        VideoPlayer(player: AVPlayer(url: video)).frame(height: 300)
                        Button(starred.contains(video.lastPathComponent) ? L("★ Đã gắn sao", "★ Starred") : L("☆ Gắn sao (giữ lại)", "☆ Star (keep)")) { toggleStar(video.lastPathComponent) }
                        if !frames.isEmpty {
                            ScrollView(.horizontal) {
                                HStack { ForEach(frames, id: \.self) { d in if let i = UIImage(data: d) { Image(uiImage: i).resizable().scaledToFit().frame(height: 140) } } }
                            }
                        }
                    }
                    Section(L("Tự kiểm tra", "Self-check")) {
                        ForEach(PostureCheck.checklist, id: \.self) { item in
                            Button { if checked.contains(item) { checked.remove(item) } else { checked.insert(item) } } label: {
                                Label(item, systemImage: checked.contains(item) ? "checkmark.square.fill" : "square")
                            }
                        }
                    }
                    Section(L("Nhờ thầy xem tư thế", "Ask a teacher to check your posture")) {
                        if let key = Keychain.get(Keychain.claudeKey), !key.isEmpty {
                            Button(working ? L("Thầy đang xem…", "Teacher is reviewing…") : L("Gửi ảnh cho Claude (API)", "Send photos to Claude (API)")) { Task { await askAPI(key) } }.disabled(working || frames.isEmpty)
                        }
                        ShareLink(items: frames.enumerated().map { FrameImage(data: $0.element, index: $0.offset) },
                                  preview: { SharePreview(L("Ảnh tư thế \($0.index + 1)", "Posture photo \($0.index + 1)")) }) {
                            Label(L("Gửi ảnh sang app Claude (gói Pro)", "Send photos to the Claude app (Pro plan)"), systemImage: "square.and.arrow.up")
                        }
                        .simultaneousGesture(TapGesture().onEnded { UIPasteboard.general.string = PostureCheck.prompt(exercise: exerciseTitle, date: Date()) })
                        Text(L("Lời nhắn kèm checklist đã được copy — dán vào Project \"Thầy dạy trống\" cùng các ảnh.", "The message with the checklist is copied. Paste it into the \"Drum teacher\" Project along with the photos.")).font(.caption).foregroundStyle(.secondary)
                        if let review {
                            ForEach(review.good, id: \.self) { Label($0, systemImage: "checkmark.circle").foregroundStyle(.green) }
                            ForEach(review.fix, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                            Text(L("Bài tập: \(review.drill)", "Exercise: \(review.drill)")).bold()
                        }
                        if let message { Text(message).foregroundStyle(.orange) }
                    }
                }
            }
            .navigationTitle(L("Soi tư thế", "Check posture"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Xong", "Done")) { dismiss() } } }
            .task {
                PracticeRecorder.cleanUp(starred: starred)
                allowed = await recorder.configure()
            }
            .onChange(of: recorder.lastVideo) { _, url in
                guard let url else { return }
                Task { frames = await PracticeRecorder.frames(from: url) }
            }
            .onDisappear { recorder.stop() }
        }
    }

    private var starred: Set<String> { Set(starredRaw.split(separator: "|").map(String.init)) }
    private func toggleStar(_ name: String) {
        var s = starred
        if s.contains(name) { s.remove(name) } else { s.insert(name) }
        starredRaw = s.sorted().joined(separator: "|")
    }

    private func askAPI(_ key: String) async {
        working = true; defer { working = false }
        do { review = try await PostureCheck.review(frames: frames, exercise: exerciseTitle, client: ClaudeClient(apiKey: key, model: model)) }
        catch { message = error.userMessage }
    }
}

struct FrameImage: Transferable {
    let data: Data
    let index: Int
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .jpeg) { $0.data } }
}
