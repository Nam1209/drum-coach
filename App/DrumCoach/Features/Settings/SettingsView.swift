import DrumAI
import DrumAudio
import DrumCore
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
    @AppStorage(AppLocale.key) private var language = "system"
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeader(title: L("Cài đặt", "Settings"))
                HStack(alignment: .top, spacing: 22) {
                    VStack(spacing: 26) {
                        CardSection(L("Thiết bị", "Devices"), footer: L("Bật hi-hat theo pedal nếu kit gửi cùng một nốt cho hi-hat mở và đóng: app đọc vị trí pedal để biết bạn đánh mở hay đóng.", "Turn on hi-hat by pedal if your kit sends the same note for open and closed hi-hat: the app reads the pedal position to tell which one you played.")) {
                            DrumStatusPill(inCard: true)
                            BluetoothMIDIButton()
                            CardButton(L("Hiệu chỉnh độ trễ pad và trống điện", "Latency calibration for pad and e-drum kit"), systemImage: "dot.radiowaves.left.and.right") { showCalibration = true }
                            CardLink("MIDI learn (Roland TD-4K)", subtitle: L("Gán nốt MIDI cho từng trống, xem nốt đang đánh", "Map MIDI notes to each drum and see the note you hit")) { MIDILearnView() }
                            Toggle(L("Hi-hat mở/đóng theo pedal (CC4)", "Open/closed hi-hat by pedal (CC4)"), isOn: $hiHatByPedal)
                        }
                        CardSection(L("Ngôn ngữ", "Language")) {
                            Picker(L("Ngôn ngữ", "Language"), selection: $language) {
                                Text(L("Theo máy", "System")).tag("system"); Text("Tiếng Việt").tag("vi"); Text("English").tag("en")
                            }
                            .pickerStyle(.segmented)
                        }
                        CardSection(L("Nhắc tập", "Practice reminder")) {
                            Stepper(L("Giờ nhắc hằng ngày: \(reminderHour):00", "Daily reminder time: \(reminderHour):00"), value: $reminderHour, in: 5...23)
                                .onChange(of: reminderHour) {
                                    Task { if await ReminderScheduler.requestPermission() { ReminderScheduler.schedule(today: nil, practicedToday: sessions.first.map { Calendar.current.isDateInToday($0.date) } ?? false) } }
                                }
                        }
                        CardSection(L("Bản cài", "Installation"), footer: L("Cài bằng Apple ID miễn phí: app hết hạn sau 7 ngày. Cắm iPad vào Mac và bấm Run trong Xcode để cài lại, lịch sử tập vẫn giữ nguyên.", "Installed with a free Apple ID: the app expires after 7 days. Connect the iPad to your Mac and press Run in Xcode to reinstall; your practice history is kept.")) {
                            if let exp = ReminderScheduler.expiryDate {
                                LabeledContent(L("Hết hạn", "Expires"), value: exp.formatted(date: .abbreviated, time: .shortened))
                            } else {
                                Text(L("Chưa rõ ngày hết hạn", "Expiry date unknown")).foregroundStyle(.secondary)
                            }
                        }
                    }
                    VStack(spacing: 26) {
                        CardSection(L("Claude API (tùy chọn)", "Claude API (optional)"), footer: L("Không bắt buộc. Không có key, app dùng gói Claude Pro qua Notion. Có key thì thầy AI và đọc PDF chạy tự động (tính phí API riêng, khoảng 2–5 USD mỗi tháng).", "Optional. Without a key, the app uses your Claude Pro plan through Notion. With a key, the AI teacher and PDF reading run automatically (billed separately by the API, about 2–5 USD a month).")) {
                            SecureField("sk-ant-…", text: $apiKey)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .onSubmit { Keychain.set(apiKey, for: Keychain.claudeKey) }
                            LabeledContent("Model") {
                                Picker("Model", selection: $model) {
                                    Text(L("Claude Opus 5.5 (mặc định)", "Claude Opus 5.5 (default)")).tag("claude-opus-5-5")
                                    Text(L("Claude Sonnet 5.5 (rẻ hơn)", "Claude Sonnet 5.5 (cheaper)")).tag("claude-sonnet-5-5")
                                }
                                .labelsHidden()
                            }
                            CardButton(L("Lưu key", "Save key"), systemImage: "key") { Keychain.set(apiKey, for: Keychain.claudeKey) }
                        }
                        CardSection(L("Giọng đếm của bạn", "Your counting voice"), footer: L("Bấm Ghi âm rồi nói rõ một âm (\"one\", \"and\"…). Xóa để quay về giọng máy (có hiệu lực sau khi mở lại app).", "Press Record and say one sound clearly (\"one\", \"and\"…). Delete to go back to the built-in voice (takes effect after you reopen the app).")) {
                            ForEach(VoiceRecorder.labels, id: \.self) { label in
                                HStack {
                                    Text(label == "&" ? "& (and)" : label).font(Theme.number(17)).frame(width: 70, alignment: .leading)
                                    Text(VoiceRecorder.hasRecording(label) ? L("Giọng của bạn", "Your voice") : L("Giọng máy", "Built-in voice")).foregroundStyle(.secondary)
                                    Spacer()
                                    if VoiceRecorder.hasRecording(label) {
                                        Button(L("Xóa", "Delete"), role: .destructive) { VoiceRecorder.delete(label); refresh += 1 }.buttonStyle(.borderless)
                                    }
                                    Button(recorder.recordingLabel == label ? L("Đang ghi…", "Recording…") : L("Ghi âm", "Record")) {
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
