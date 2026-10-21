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

/// A titled group of rows on one rounded surface (the app's replacement for grouped lists):
/// every child becomes a padded row, with hairlines between rows.
struct CardSection<Content: View>: View {
    var title: String?
    var trailing: String?
    var footer: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, trailing: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.trailing = trailing; self.footer = footer; self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.title3.weight(.semibold))
                    Spacer()
                    if let trailing { Text(trailing).font(Theme.number(15, weight: .medium)).foregroundStyle(.secondary) }
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(rows) { row in
                        row
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if row.id != rows.last?.id { Divider().padding(.leading, 18) }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.stage))
            if let footer { Text(footer).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// A row that opens another screen: title, optional detail line, optional value, chevron.
struct CardLink<Destination: View>: View {
    let title: String
    var subtitle: String?
    var value: String?
    @ViewBuilder var destination: () -> Destination

    init(_ title: String, subtitle: String? = nil, value: String? = nil, @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title; self.subtitle = subtitle; self.value = value; self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).foregroundStyle(.primary).multilineTextAlignment(.leading)
                    if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer()
                if let value { Text(value).font(Theme.number(15, weight: .medium)).foregroundStyle(.secondary) }
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A row that does something right away (accent text, or red for destructive actions).
struct CardButton: View {
    let title: String
    var systemImage: String?
    var role: ButtonRole?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title; self.systemImage = systemImage; self.role = role; self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
                Spacer()
            }
            .foregroundStyle(role == .destructive ? Theme.missed : Theme.shell)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
