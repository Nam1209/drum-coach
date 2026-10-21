import AVKit
import DrumAI
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
                        Button(recorder.isRecording ? "⏹ Dừng ghi" : "⏺ Ghi lại lần tập") { recorder.toggleRecording() }
                    } else {
                        Text("Cần quyền dùng camera trong Cài đặt iPad.").foregroundStyle(.red)
                    }
                } footer: {
                    Text("Đặt iPad sao cho thấy cả hai tay và vai. Video chỉ lưu trên máy, tự xóa sau 30 ngày trừ khi gắn sao.")
                }
                if let video = recorder.lastVideo {
                    Section("Lần ghi vừa rồi") {
                        VideoPlayer(player: AVPlayer(url: video)).frame(height: 300)
                        Button(starred.contains(video.lastPathComponent) ? "★ Đã gắn sao" : "☆ Gắn sao (giữ lại)") { toggleStar(video.lastPathComponent) }
                        if !frames.isEmpty {
                            ScrollView(.horizontal) {
                                HStack { ForEach(frames, id: \.self) { d in if let i = UIImage(data: d) { Image(uiImage: i).resizable().scaledToFit().frame(height: 140) } } }
                            }
                        }
                    }
                    Section("Tự kiểm tra") {
                        ForEach(PostureCheck.checklist, id: \.self) { item in
                            Button { if checked.contains(item) { checked.remove(item) } else { checked.insert(item) } } label: {
                                Label(item, systemImage: checked.contains(item) ? "checkmark.square.fill" : "square")
                            }
                        }
                    }
                    Section("Nhờ thầy xem tư thế") {
                        if let key = Keychain.get(Keychain.claudeKey), !key.isEmpty {
                            Button(working ? "Thầy đang xem…" : "Gửi ảnh cho Claude (API)") { Task { await askAPI(key) } }.disabled(working || frames.isEmpty)
                        }
                        ShareLink(items: frames.enumerated().map { FrameImage(data: $0.element, index: $0.offset) },
                                  preview: { SharePreview("Ảnh tư thế \($0.index + 1)") }) {
                            Label("Gửi ảnh sang app Claude (gói Pro)", systemImage: "square.and.arrow.up")
                        }
                        .simultaneousGesture(TapGesture().onEnded { UIPasteboard.general.string = PostureCheck.prompt(exercise: exerciseTitle, date: Date()) })
                        Text("Lời nhắn kèm checklist đã được copy — dán vào Project \"Thầy dạy trống\" cùng các ảnh.").font(.caption).foregroundStyle(.secondary)
                        if let review {
                            ForEach(review.good, id: \.self) { Label($0, systemImage: "checkmark.circle").foregroundStyle(.green) }
                            ForEach(review.fix, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                            Text("Bài tập: \(review.drill)").bold()
                        }
                        if let message { Text(message).foregroundStyle(.orange) }
                    }
                }
            }
            .navigationTitle("Soi tư thế")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Xong") { dismiss() } } }
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
        catch { message = "Không gửi được: \(error)" }
    }
}

struct FrameImage: Transferable {
    let data: Data
    let index: Int
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .jpeg) { $0.data } }
}
