import DrumCore
import SwiftUI

/// Draws an exercise on percussion staves with a moving playhead.
struct NotationView: View {
    let exercise: Exercise
    let display: NotationDisplay
    /// Beats since the end of the count-in (negative during it); nil when stopped.
    let beat: Double?
    /// Result colour of a note (index into `exercise.notes`) in a pass through the exercise.
    var noteColor: (_ noteIndex: Int, _ pass: Int) -> Color? = { _, _ in nil }
    /// Early (negative) / late (positive) offset in ms for orange notes.
    var orangeOffsetMs: (_ noteIndex: Int, _ pass: Int) -> Double? = { _, _ in nil }
    var showVoiceLabels = true
    /// Tempo, so a note stays visible just long enough after the playhead for its result to show.
    var bpm: Double = 60
    /// Last pass of the run; the scrolling line draws nothing after it.
    var lastPass = 0

    private let spacing: Double = 12
    private var lineHeight: Double { spacing * 4 + 110 }

    /// Printing lays out every line instead of scrolling.
    var allPages = false
    /// Page mode shows this many lines at a time; the playing line sits on top so the next one is always in view.
    private var visibleLines: Int { allPages ? max(1, lineCount) : 2 }
    @State private var width: Double = 900
    @State private var manualLine = 0

    private var barsPerLine: Int { display == .page ? max(1, min(exercise.bars, width > 900 ? 2 : 1)) : max(exercise.bars, 1) }
    private var lineCount: Int { (max(exercise.bars, 1) + barsPerLine - 1) / barsPerLine }
    private var lastFirstLine: Int { max(0, lineCount - visibleLines) }

    var body: some View {
        let perLine = barsPerLine
        let barWidth = display == .page ? (width - 40) / Double(perLine) : max(width * 0.55, 420)
        let layout = NotationLayout(exercise: exercise, barWidth: barWidth, barsPerLine: perLine, staffSpacing: spacing)
        let playing = (beat ?? -1) >= 0
        let currentLine = playing ? layout.playheadX(atBeat: Rational(Int(((beat ?? 0) * 1000).rounded()), 1000)).line : manualLine
        let firstLine = playing ? NotationScroll.firstVisibleLine(current: currentLine, lineCount: lineCount, visible: visibleLines)
                                : min(manualLine, lastFirstLine)
        let pass = playing ? Int((beat ?? 0) / exercise.lengthInBeats.doubleValue) : 0
        VStack(alignment: .trailing, spacing: 6) {
            Group {
                if display == .page {
                    // Every line is drawn; the window slides up smoothly so the eye never loses its place.
                    Canvas { ctx, _ in
                        ctx.translateBy(x: 20, y: 0)
                        drawStaves(layout, &ctx)
                        drawNotes(layout, &ctx, labels: true, pass: pass)
                        drawPlayhead(layout, &ctx)
                    }
                    .frame(height: lineHeight * Double(lineCount))
                    .offset(y: -Double(firstLine) * lineHeight)
                    .animation(.easeInOut(duration: 0.35), value: firstLine)
                    .frame(height: lineHeight * Double(min(visibleLines, lineCount)), alignment: .top)
                    .clipped()
                } else {
                    Canvas { ctx, size in drawScrolling(in: &ctx, size: size) }
                        .frame(height: lineHeight)
                }
            }
            .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
            if display == .page, lineCount > visibleLines {
                HStack(spacing: 14) {
                    if playing, currentLine == lineCount - 1 {
                        Label(L("Tiếp theo: quay lại ô 1", "Next: back to bar 1"), systemImage: "arrow.uturn.up")
                            .font(.footnote.weight(.semibold)).foregroundStyle(Theme.shell)
                    }
                    Spacer()
                    let firstBar = firstLine * perLine + 1
                    let lastBar = min(exercise.bars, (firstLine + visibleLines) * perLine)
                    Text(L("Ô \(firstBar)–\(lastBar)/\(exercise.bars)", "Bars \(firstBar)–\(lastBar) of \(exercise.bars)"))
                        .font(Theme.number(13, weight: .medium)).foregroundStyle(.secondary)
                    Button { manualLine = max(0, firstLine - 1) } label: { Image(systemName: "chevron.up") }
                        .disabled(playing || firstLine == 0).accessibilityLabel(L("Dòng trước", "Previous line"))
                    Button { manualLine = min(lastFirstLine, firstLine + 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(playing || firstLine >= lastFirstLine).accessibilityLabel(L("Dòng sau", "Next line"))
                }
                .font(.callout.weight(.semibold))
            }
        }
        .onChange(of: exercise.id) { manualLine = 0 }
    }

    private func y(line: Int, step: Int) -> Double {
        let bottom = 40 + spacing * 4 + Double(line) * lineHeight
        return bottom - Double(step) * spacing / 2
    }

    /// One staff moving left under a fixed playhead: pass after pass of the exercise, so a short exercise never jumps
    /// back to its start. Notes vanish just after the playhead, once their result has had time to show.
    private func drawScrolling(in ctx: inout GraphicsContext, size: CGSize) {
        let ppb = ScrollWindow.pixelsPerBeat(width: size.width, exercise: exercise)
        let barBeats = exercise.timeSignature.beatsInQuarters.doubleValue
        let layout = NotationLayout(exercise: exercise, barWidth: barBeats * ppb, barsPerLine: max(exercise.bars, 1),
                                    staffSpacing: spacing, padding: 0)
        let length = exercise.lengthInBeats.doubleValue
        let now = beat ?? 0
        let headX = size.width * ScrollWindow.headFraction
        // A missed note is only known ~0.2 s after its time, so keep each note 0.3 s past the playhead.
        let hideX = headX - 0.3 * bpm / 60 * ppb

        var staff = Path()
        for k in 0..<5 {
            let yy = y(line: 0, step: k * 2)
            staff.move(to: CGPoint(x: hideX, y: yy)); staff.addLine(to: CGPoint(x: size.width, y: yy))
        }
        ctx.stroke(staff, with: .color(.secondary.opacity(0.35)), lineWidth: 1)

        var visible = ctx
        visible.clip(to: Path(CGRect(x: hideX, y: 0, width: size.width - hideX, height: size.height)))
        let behind = (headX - hideX) / ppb + 1, ahead = (size.width - headX) / ppb + 1
        if let passes = ScrollWindow.repeats(beat: now, lengthBeats: length, behindBeats: behind, aheadBeats: ahead, lastRepeat: lastPass) {
            for pass in passes {
                var c = visible
                c.translateBy(x: headX + (Double(pass) * length - now) * ppb, y: 0)
                // Bar lines sit a little before the bar's first note so they don't cut through it.
                var bars = Path()
                for b in 0..<max(exercise.bars, 1) {
                    let x = Double(b) * layout.barWidth - 14
                    bars.move(to: CGPoint(x: x, y: y(line: 0, step: 8))); bars.addLine(to: CGPoint(x: x, y: y(line: 0, step: 0)))
                }
                c.stroke(bars, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
                drawNotes(layout, &c, labels: false, pass: pass)
            }
        }

        let rect = CGRect(x: headX - 5, y: y(line: 0, step: 14), width: 10, height: y(line: 0, step: -4) - y(line: 0, step: 14))
        ctx.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Theme.ink.opacity(0.12)))
    }

    private func drawStaves(_ l: NotationLayout, _ ctx: inout GraphicsContext) {
        let width = l.barWidth * Double(l.barsPerLine)
        for line in 0..<l.lineCount {
            var p = Path()
            for k in 0..<5 {
                let yy = y(line: line, step: k * 2)
                p.move(to: CGPoint(x: 0, y: yy)); p.addLine(to: CGPoint(x: width, y: yy))
            }
            for b in 0...l.barsPerLine {
                let x = Double(b) * l.barWidth
                p.move(to: CGPoint(x: x, y: y(line: line, step: 8))); p.addLine(to: CGPoint(x: x, y: y(line: line, step: 0)))
            }
            ctx.stroke(p, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
        }
    }

    private func drawNotes(_ l: NotationLayout, _ ctx: inout GraphicsContext, labels: Bool, pass: Int) {
        let stemTopStep = 13
        var seenVoices = Set<Voice>()
        let stacks = Dictionary(grouping: l.glyphs) { "\($0.line)-\(Int($0.x * 10))" }
        for stack in stacks.values.sorted(by: { ($0[0].line, $0[0].x) < ($1[0].line, $1[0].x) }) {
            let lowest = stack.min { $0.staffStep < $1.staffStep }!
            let color = stack.compactMap { noteColor($0.noteIndex, pass) }.first ?? .primary
            var stem = Path()
            stem.move(to: CGPoint(x: lowest.x + 6, y: y(line: lowest.line, step: lowest.staffStep)))
            stem.addLine(to: CGPoint(x: lowest.x + 6, y: y(line: lowest.line, step: stemTopStep)))
            ctx.stroke(stem, with: .color(color), lineWidth: 1.6)
            for g in stack {
                let gc = noteColor(g.noteIndex, pass) ?? .primary
                let cy = y(line: g.line, step: g.staffStep)
                if g.xHead {
                    var x = Path()
                    x.move(to: CGPoint(x: g.x - 5, y: cy - 5)); x.addLine(to: CGPoint(x: g.x + 5, y: cy + 5))
                    x.move(to: CGPoint(x: g.x + 5, y: cy - 5)); x.addLine(to: CGPoint(x: g.x - 5, y: cy + 5))
                    ctx.stroke(x, with: .color(gc), lineWidth: 2)
                } else {
                    let head = Path(ellipseIn: CGRect(x: g.x - 7, y: cy - 5, width: 13, height: 10))
                    ctx.fill(head.applying(CGAffineTransform(translationX: -g.x, y: -cy).concatenating(.init(rotationAngle: -0.35)).concatenating(.init(translationX: g.x, y: cy))), with: .color(gc))
                }
                if g.ghost {
                    ctx.draw(Text("(").font(.system(size: 16)).foregroundColor(gc), at: CGPoint(x: g.x - 12, y: cy))
                    ctx.draw(Text(")").font(.system(size: 16)).foregroundColor(gc), at: CGPoint(x: g.x + 12, y: cy))
                }
                if g.accent {
                    ctx.draw(Text(">").font(.system(size: 18, weight: .bold)).foregroundColor(gc),
                             at: CGPoint(x: g.x + 6, y: y(line: g.line, step: stemTopStep + 3)))
                }
                if let h = g.hand, h != .foot {
                    ctx.draw(Text(h.rawValue).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(h == .right ? Theme.ink : .secondary),
                             at: CGPoint(x: g.x, y: y(line: g.line, step: -5)))
                }
                if let ms = orangeOffsetMs(g.noteIndex, pass) {
                    let gap = 9 + min(abs(ms), 80) * 0.25
                    let mx = ms < 0 ? g.x - gap - 4 : g.x + gap + 6
                    ctx.fill(Path(roundedRect: CGRect(x: mx - 2, y: cy - 13, width: 4, height: 26), cornerRadius: 2), with: .color(Theme.offTime))
                    ctx.draw(Text(String(format: "%+.0f", ms)).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(Theme.offTime),
                             at: CGPoint(x: g.x, y: y(line: g.line, step: stemTopStep + 6)))
                }
                let v = exercise.notes[g.noteIndex].voice
                if labels, showVoiceLabels, !seenVoices.contains(v) {
                    seenVoices.insert(v)
                    ctx.draw(Text(v.localizedName).font(.caption.weight(.semibold)).foregroundColor(.secondary),
                             at: CGPoint(x: g.x - 14, y: cy), anchor: .trailing)
                }
            }
        }
        for b in l.beams {
            for k in 0..<b.level {
                let by = y(line: b.line, step: stemTopStep) + Double(k) * 7
                ctx.fill(Path(CGRect(x: b.fromX + 6, y: by, width: b.toX - b.fromX + 1.6, height: 4.5)), with: .color(.primary))
            }
        }
    }

    private func drawPlayhead(_ l: NotationLayout, _ ctx: inout GraphicsContext) {
        guard let beat, beat >= 0 else { return }
        let p = l.playheadX(atBeat: Rational(Int((beat * 1000).rounded()), 1000))
        let rect = CGRect(x: p.x - 5, y: y(line: p.line, step: 14), width: 10, height: y(line: p.line, step: -4) - y(line: p.line, step: 14))
        ctx.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Theme.ink.opacity(0.12)))
    }
}
