import DrumCore
import SwiftUI

/// Draws an exercise on percussion staves with a moving playhead.
struct NotationView: View {
    let exercise: Exercise
    let display: NotationDisplay
    /// Beats since the start of the exercise (wrapping per repeat); nil when stopped.
    let beat: Double?
    var noteColor: (Int) -> Color? = { _ in nil }
    /// Early (negative) / late (positive) offset in ms for orange notes.
    var orangeOffsetMs: (Int) -> Double? = { _ in nil }
    var showVoiceLabels = true

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
        VStack(alignment: .trailing, spacing: 6) {
            Group {
                if display == .page {
                    // Every line is drawn; the window slides up smoothly so the eye never loses its place.
                    Canvas { ctx, _ in
                        ctx.translateBy(x: 20, y: 0)
                        draw(layout, in: &ctx, copies: 1)
                    }
                    .frame(height: lineHeight * Double(lineCount))
                    .offset(y: -Double(firstLine) * lineHeight)
                    .animation(.easeInOut(duration: 0.35), value: firstLine)
                    .frame(height: lineHeight * Double(min(visibleLines, lineCount)), alignment: .top)
                    .clipped()
                } else {
                    Canvas { ctx, size in
                        let head = layout.playheadX(atBeat: Rational(Int(((beat ?? 0) * 1000).rounded()), 1000))
                        let total = barWidth * Double(exercise.bars)
                        ctx.translateBy(x: size.width * 0.3 - head.x, y: 0)
                        ctx.translateBy(x: -total, y: 0)
                        draw(layout, in: &ctx, copies: 3, copyWidth: total)
                    }
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

    private func draw(_ l: NotationLayout, in ctx: inout GraphicsContext, copies: Int, copyWidth: Double = 0) {
        for copy in 0..<copies {
            var c = ctx
            c.translateBy(x: Double(copy) * copyWidth, y: 0)
            drawStaves(l, &c)
            drawNotes(l, &c, labels: copy == (copies > 1 ? 1 : 0))
        }
        drawPlayhead(l, &ctx, offset: copies > 1 ? copyWidth : 0)
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

    private func drawNotes(_ l: NotationLayout, _ ctx: inout GraphicsContext, labels: Bool) {
        let stemTopStep = 13
        var seenVoices = Set<Voice>()
        let stacks = Dictionary(grouping: l.glyphs) { "\($0.line)-\(Int($0.x * 10))" }
        for stack in stacks.values.sorted(by: { ($0[0].line, $0[0].x) < ($1[0].line, $1[0].x) }) {
            let lowest = stack.min { $0.staffStep < $1.staffStep }!
            let color = stack.compactMap { noteColor($0.noteIndex) }.first ?? .primary
            var stem = Path()
            stem.move(to: CGPoint(x: lowest.x + 6, y: y(line: lowest.line, step: lowest.staffStep)))
            stem.addLine(to: CGPoint(x: lowest.x + 6, y: y(line: lowest.line, step: stemTopStep)))
            ctx.stroke(stem, with: .color(color), lineWidth: 1.6)
            for g in stack {
                let gc = noteColor(g.noteIndex) ?? .primary
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
                if let ms = orangeOffsetMs(g.noteIndex) {
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

    private func drawPlayhead(_ l: NotationLayout, _ ctx: inout GraphicsContext, offset: Double) {
        guard let beat, beat >= 0 else { return }
        let p = l.playheadX(atBeat: Rational(Int((beat * 1000).rounded()), 1000))
        let rect = CGRect(x: offset + p.x - 5, y: y(line: p.line, step: 14), width: 10, height: y(line: p.line, step: -4) - y(line: p.line, step: 14))
        ctx.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Theme.ink.opacity(0.12)))
    }
}
