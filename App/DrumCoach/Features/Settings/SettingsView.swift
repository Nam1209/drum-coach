import DrumAI
import DrumAudio
import SwiftUI

struct SettingsView: View {
    let voiceBank: CountVoiceBank
    @State private var apiKey = Keychain.get(Keychain.claudeKey) ?? ""
    @AppStorage("claude.model") private var model = ClaudeClient.defaultModel
    @StateObject private var recorder = VoiceRecorder()
    @State private var showCalibration = false
    @State private var refresh = 0
    @State private var error: String?
    @AppStorage("reminderHour") private var reminderHour = 19

    var body: some View {
        Form {
            Section {
                SecureField("sk-ant-…", text: $apiKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onSubmit { Keychain.set(apiKey, for: Keychain.claudeKey) }
                Picker("Model", selection: $model) {
                    Text("Claude Opus 5.5 (mặc định)").tag("claude-opus-5-5")
                    Text("Claude Sonnet 5.5 (rẻ hơn)").tag("claude-sonnet-5-5")
                }
                Button("Lưu key") { Keychain.set(apiKey, for: Keychain.claudeKey) }
            } header: {
                Text("Claude API (tùy chọn)")
            } footer: {
                Text("Không bắt buộc. Không có key, app dùng gói Claude Pro qua Notion. Có key thì thầy AI và đọc PDF chạy tự động (tính phí API riêng, khoảng $2–5/tháng).")
            }
            Section("Nhắc tập") {
                Stepper("Giờ nhắc hằng ngày: \(reminderHour):00", value: $reminderHour, in: 5...23)
            }
            Section("Thiết bị") {
                Button("Hiệu chỉnh độ trễ pad / trống điện") { showCalibration = true }
                NavigationLink("MIDI learn (Roland TD-7)") { MIDILearnView() }
            }
            Section {
                ForEach(VoiceRecorder.labels, id: \.self) { label in
                    HStack {
                        Text(label == "&" ? "& (and)" : label).font(.headline).frame(width: 70, alignment: .leading)
                        Text(VoiceRecorder.hasRecording(label) ? "Giọng của bạn" : "Giọng máy").foregroundStyle(.secondary)
                        Spacer()
                        Button(recorder.recordingLabel == label ? "Đang ghi…" : "Ghi âm") {
                            Task {
                                do { try await recorder.record(label, into: voiceBank); refresh += 1 }
                                catch { self.error = error.localizedDescription }
                            }
                        }
                        .disabled(recorder.recordingLabel != nil)
                        if VoiceRecorder.hasRecording(label) {
                            Button("Xóa", role: .destructive) { VoiceRecorder.delete(label); refresh += 1 }
                        }
                    }
                }
                .id(refresh)
                if let error { Text(error).foregroundStyle(.red) }
            } header: {
                Text("Giọng đếm của bạn")
            } footer: {
                Text("Bấm Ghi âm rồi nói rõ một âm (\"one\", \"and\"…). Xóa để quay về giọng máy (có hiệu lực sau khi mở lại app).")
            }
            Section("Bản cài") {
                if let exp = ReminderScheduler.expiryDate {
                    LabeledContent("Ngày hết hạn bản cài", value: exp.formatted(date: .abbreviated, time: .shortened))
                }
                Text("Cài bằng Apple ID miễn phí: app hết hạn sau 7 ngày. Cắm iPad vào Mac và bấm Run trong Xcode để cài lại — lịch sử tập vẫn giữ nguyên.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Cài đặt")
        .sheet(isPresented: $showCalibration) { CalibrationView(voiceBank: voiceBank) }
    }
}
