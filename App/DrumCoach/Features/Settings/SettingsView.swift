import DrumAI
import DrumAudio
import SwiftData
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
    @AppStorage("hiHatByPedal") private var hiHatByPedal = false
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(title: "Cài đặt")
                HStack(alignment: .top, spacing: 22) {
                    VStack(spacing: 26) {
                        CardSection("Thiết bị", footer: "Bật hi-hat theo pedal nếu kit gửi cùng một nốt cho hi-hat mở và đóng: app đọc vị trí pedal để biết bạn đánh mở hay đóng.") {
                            CardButton("Hiệu chỉnh độ trễ pad và trống điện", systemImage: "dot.radiowaves.left.and.right") { showCalibration = true }
                            CardLink("MIDI learn (Roland TD-7)", subtitle: "Gán nốt MIDI cho từng trống, xem nốt đang đánh") { MIDILearnView() }
                            Toggle("Hi-hat mở/đóng theo pedal (CC4)", isOn: $hiHatByPedal)
                        }
                        CardSection("Nhắc tập") {
                            Stepper("Giờ nhắc hằng ngày: \(reminderHour):00", value: $reminderHour, in: 5...23)
                                .onChange(of: reminderHour) {
                                    Task { if await ReminderScheduler.requestPermission() { ReminderScheduler.schedule(today: nil, practicedToday: sessions.first.map { Calendar.current.isDateInToday($0.date) } ?? false) } }
                                }
                        }
                        CardSection("Bản cài", footer: "Cài bằng Apple ID miễn phí: app hết hạn sau 7 ngày. Cắm iPad vào Mac và bấm Run trong Xcode để cài lại, lịch sử tập vẫn giữ nguyên.") {
                            if let exp = ReminderScheduler.expiryDate {
                                LabeledContent("Hết hạn", value: exp.formatted(date: .abbreviated, time: .shortened))
                            } else {
                                Text("Chưa rõ ngày hết hạn").foregroundStyle(.secondary)
                            }
                        }
                    }
                    VStack(spacing: 26) {
                        CardSection("Claude API (tùy chọn)", footer: "Không bắt buộc. Không có key, app dùng gói Claude Pro qua Notion. Có key thì thầy AI và đọc PDF chạy tự động (tính phí API riêng, khoảng 2–5 USD mỗi tháng).") {
                            SecureField("sk-ant-…", text: $apiKey)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .onSubmit { Keychain.set(apiKey, for: Keychain.claudeKey) }
                            LabeledContent("Model") {
                                Picker("Model", selection: $model) {
                                    Text("Claude Opus 5.5 (mặc định)").tag("claude-opus-5-5")
                                    Text("Claude Sonnet 5.5 (rẻ hơn)").tag("claude-sonnet-5-5")
                                }
                                .labelsHidden()
                            }
                            CardButton("Lưu key", systemImage: "key") { Keychain.set(apiKey, for: Keychain.claudeKey) }
                        }
                        CardSection("Giọng đếm của bạn", footer: "Bấm Ghi âm rồi nói rõ một âm (\"one\", \"and\"…). Xóa để quay về giọng máy (có hiệu lực sau khi mở lại app).") {
                            ForEach(VoiceRecorder.labels, id: \.self) { label in
                                HStack {
                                    Text(label == "&" ? "& (and)" : label).font(Theme.number(17)).frame(width: 70, alignment: .leading)
                                    Text(VoiceRecorder.hasRecording(label) ? "Giọng của bạn" : "Giọng máy").foregroundStyle(.secondary)
                                    Spacer()
                                    if VoiceRecorder.hasRecording(label) {
                                        Button("Xóa", role: .destructive) { VoiceRecorder.delete(label); refresh += 1 }.buttonStyle(.borderless)
                                    }
                                    Button(recorder.recordingLabel == label ? "Đang ghi…" : "Ghi âm") {
                                        Task {
                                            do { try await recorder.record(label, into: voiceBank); refresh += 1 }
                                            catch { self.error = error.localizedDescription }
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(recorder.recordingLabel != nil)
                                }
                                .id("\(label)-\(refresh)")
                            }
                            if let error { Text(error).foregroundStyle(Theme.missed) }
                        }
                    }
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.canvas)
        .sheet(isPresented: $showCalibration) { CalibrationView(voiceBank: voiceBank) }
    }
}
