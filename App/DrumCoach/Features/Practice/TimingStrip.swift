import DrumAnalysis
import SwiftUI

/// Last 16 hits as dots around a centre line: left = early, right = late (±60 ms).
struct TimingStrip: View {
    let recent: [(ms: Double, grade: Grade)]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, mid = w / 2, scale = (w / 2 - 12) / 60
            ZStack {
                Capsule().fill(Color(.secondarySystemBackground))
                Rectangle().fill(Color.primary.opacity(0.6)).frame(width: 2).position(x: mid, y: geo.size.height / 2)
                Text("sớm").font(.caption2).foregroundStyle(.secondary).position(x: 24, y: geo.size.height / 2)
                Text("muộn").font(.caption2).foregroundStyle(.secondary).position(x: w - 28, y: geo.size.height / 2)
                ForEach(Array(recent.enumerated()), id: \.offset) { i, r in
                    Circle().fill(r.grade.color.opacity(0.35 + 0.65 * Double(i + 1) / Double(max(recent.count, 1))))
                        .frame(width: 12, height: 12)
                        .position(x: mid + max(-60, min(60, r.ms)) * scale, y: geo.size.height / 2)
                }
            }
        }
        .frame(height: 32)
    }
}
