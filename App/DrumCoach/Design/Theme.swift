import DrumAnalysis
import SwiftUI

/// DrumCoach design tokens: one action colour (drum-shell lacquer blue), three timing colours that carry meaning,
/// rounded numerals for everything you count, and the system's own surfaces so light and dark mode just work.
enum Theme {
    /// The only accent: buttons and selection.
    static let shell = Color(red: 0.176, green: 0.294, blue: 0.847)          // #2D4BD8
    /// Timing — used for nothing else.
    static let onTime = Color(red: 0.133, green: 0.639, blue: 0.353)         // #22A35A
    static let offTime = Color(red: 0.941, green: 0.541, blue: 0.141)        // #F08A24
    static let missed = Color(red: 0.898, green: 0.282, blue: 0.302)         // #E5484D

    static let stage = Color(uiColor: .secondarySystemGroupedBackground)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let hairline = Color.primary.opacity(0.08)

    /// Numbers you play to (BPM, %, timers) are set in SF Rounded — round like a drumhead.
    static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static let pagePadding: CGFloat = 28
    static let stageRadius: CGFloat = 22
}

extension Grade {
    var color: Color {
        switch self {
        case .good: Theme.onTime
        case .early, .late: Theme.offTime
        case .missed: Theme.missed
        }
    }
}

/// The surface everything you read while playing sits on.
struct Stage<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.stageRadius, style: .continuous).fill(Theme.stage))
    }
}

/// A large number with a quiet caption under it.
struct Readout: View {
    let value: String
    let caption: String
    var size: CGFloat = 44
    var tint: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.number(size)).foregroundStyle(tint).contentTransition(.numericText())
            Text(caption).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// The round Play/Stop button. While playing, its ring beats with the pulse — the one moving thing on screen.
struct PlayButton: View {
    let isPlaying: Bool
    var beatPhase: Double = 0         // 0…1 within the current beat
    var size: CGFloat = 76
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(isPlaying ? Color.primary : Theme.shell)
                if isPlaying {
                    Circle().stroke(Theme.shell, lineWidth: 4)
                        .scaleEffect(1 + 0.18 * (1 - beatPhase))
                        .opacity(0.9 * (1 - beatPhase))
                }
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(isPlaying ? Color(uiColor: .systemBackground) : .white)
                    .offset(x: isPlaying ? 0 : size * 0.03)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Dừng" : "Bắt đầu")
        .sensoryFeedback(.impact, trigger: isPlaying)
    }
}

/// − 72 + tempo control.
struct TempoControl: View {
    @Binding var bpm: Double
    var range: ClosedRange<Double> = 30...300
    var disabled = false

    var body: some View {
        HStack(spacing: 14) {
            step("minus", -1)
            VStack(spacing: 0) {
                Text("\(Int(bpm))").font(Theme.number(56, weight: .bold)).contentTransition(.numericText())
                Text("BPM").font(.footnote).foregroundStyle(.secondary)
            }
            .frame(minWidth: 112)
            step("plus", 1)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func step(_ icon: String, _ d: Double) -> some View {
        Button { bpm = min(range.upperBound, max(range.lowerBound, bpm + d)) } label: {
            Image(systemName: icon).font(.title3.weight(.semibold)).frame(width: 46, height: 46)
                .background(Circle().fill(Theme.hairline))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }
}

/// Page title used at the top of every screen's content (large, left-aligned, no eyebrow).
struct PageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.largeTitle.weight(.bold))
                if let subtitle { Text(subtitle).foregroundStyle(.secondary) }
            }
            Spacer()
            trailing
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) { self.init(title: title, subtitle: subtitle) { EmptyView() } }
}
