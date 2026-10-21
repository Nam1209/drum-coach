import DrumCore
import SwiftUI

/// Drum Journal–style lanes: R on top, L below, counting labels on the axis, fixed "now" line in the middle.
struct RLStripView: View {
    let timeline: Timeline?
    let exercise: Exercise
    let countMode: CountMode
    /// Beats since the end of the count-in (negative during count-in).
    let beat: Double?
    var noteColor: (TimedNote) -> Color? = { _ in nil }

    private let beatsVisible = 4.0

    var body: some View {
        Canvas { ctx, size in
            let mid = size.width * 0.5, pxPerBeat = size.width / beatsVisible
            let now = beat ?? 0
            let axisY = size.height / 2
            var axis = Path()
            axis.move(to: CGPoint(x: 40, y: axisY)); axis.addLine(to: CGPoint(x: size.width - 8, y: axisY))
            ctx.stroke(axis, with: .color(.secondary.opacity(0.3)))

            // Counting labels for the visible beats.
            let beatsPerBar = Int(exercise.timeSignature.beatsInQuarters.doubleValue.rounded())
            let first = Int((now - beatsVisible / 2).rounded(.down)) - 1
            for b in first...(first + Int(beatsVisible) + 2) {
                for item in Counting.labels(mode: countMode, beats: 1) {
                    let pos = Double(b) + item.position.doubleValue
                    let x = mid + (pos - now) * pxPerBeat
                    guard x > 44, x < size.width - 8 else { continue }
                    let label = item.position == Rational(0, 1) ? "\(((b % beatsPerBar) + beatsPerBar) % beatsPerBar + 1)" : item.label
                    ctx.draw(Text(label).font(.caption.weight(.bold)).foregroundColor(.secondary), at: CGPoint(x: x, y: axisY))
                }
            }

            // Notes with a hand.
            if let timeline {
                let countIn = exercise.timeSignature.beatsInQuarters.doubleValue * Double(PracticeViewModel.countInBars)
                for tn in timeline.notes {
                    guard let hand = tn.note.hand, hand != .foot else { continue }
                    let pos = tn.time * timeline.bpm / 60 - countIn
                    let x = mid + (pos - now) * pxPerBeat
                    guard x > 44, x < size.width - 8 else { continue }
                    let top = hand == .right
                    let rect = CGRect(x: x - 3, y: top ? axisY - 44 : axisY + 16, width: 6, height: 28)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(noteColor(tn) ?? .secondary.opacity(0.25)))
                }
            }

            var nowLine = Path()
            nowLine.move(to: CGPoint(x: mid, y: 6)); nowLine.addLine(to: CGPoint(x: mid, y: size.height - 6))
            ctx.stroke(nowLine, with: .color(Theme.shell), lineWidth: 2)
            ctx.draw(Text("R").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Theme.shell), at: CGPoint(x: 20, y: axisY - 30))
            ctx.draw(Text("L").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.secondary), at: CGPoint(x: 20, y: axisY + 30))
        }
        .frame(height: 112)
    }
}
