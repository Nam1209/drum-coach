/// What the learner practises on today.
public enum PracticeInstrument: String, CaseIterable, Codable, Sendable {
    case pad, kit, both
}

extension Exercise {
    /// True when the exercise uses more than one surface or the feet (grooves, toms, cymbals), so it needs the kit.
    public var needsKit: Bool { notes.contains { $0.voice != .snare && $0.voice != .sideStick } }

    /// The hands of the exercise on a single practice pad: every hand stroke becomes a snare stroke with its sticking,
    /// the feet are dropped, and strokes that fall together merge into one (the strongest one wins).
    public func padVersion() -> Exercise {
        guard needsKit else { return self }
        func strength(_ a: Articulation) -> Int {
            switch a { case .accent: 3; case .flam, .drag, .buzz: 2; case .normal: 1; case .ghost: 0 }
        }
        var byPosition: [Rational: NoteEvent] = [:]
        for n in notes where n.hand != .foot && n.voice != .kick && n.voice != .hiHatPedal {
            let stroke = NoteEvent(position: n.position, voice: .snare, hand: n.hand, articulation: n.articulation)
            if let kept = byPosition[n.position], strength(kept.articulation) >= strength(stroke.articulation) { continue }
            byPosition[n.position] = stroke
        }
        return Exercise(id: Exercise.stableID(for: "pad|\(id.uuidString)"), title: L("\(title) (trên pad)", "\(title) (on pad)"),
                        source: source, timeSignature: timeSignature, bars: bars, suggestedTempo: suggestedTempo,
                        notes: byPosition.values.sorted { $0.position < $1.position })
    }
}
