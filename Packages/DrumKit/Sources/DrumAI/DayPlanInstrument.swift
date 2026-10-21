import DrumCore

extension DayPlan {
    /// Where a segment (0 warm-up, 1 main, 2 fun) is played: on "both" days the warm-up is on the pad, the rest on the kit.
    public static func surface(forSegment segment: Int, on instrument: PracticeInstrument) -> PracticeInstrument {
        switch instrument {
        case .pad: .pad
        case .kit: .kit
        case .both: segment == 0 ? .pad : .kit
        }
    }

    /// The same day for today's instrument: exercises that need the kit become their pad version in pad segments.
    public func adapted(to instrument: PracticeInstrument, catalog: [String: Exercise]) -> DayPlan {
        func fit(_ items: [PlannedItem], segment: Int) -> [PlannedItem] {
            guard Self.surface(forSegment: segment, on: instrument) == .pad else { return items }
            return items.map { item in
                let exercise = item.exerciseId.flatMap { catalog[$0] } ?? item.newExerciseDSL.flatMap { try? ExerciseDSL.parse($0) }
                guard let exercise, exercise.needsKit else { return item }
                let pad = exercise.padVersion()
                return PlannedItem(exerciseId: nil, newExerciseDSL: ExerciseDSL.serialize(pad, grid: ExerciseDSL.grid(for: pad)),
                                   bpm: item.bpm, minutes: item.minutes, focus: item.focus)
            }
        }
        return DayPlan(day: day, warmup: fit(warmup, segment: 0), main: fit(main, segment: 1), fun: fit(fun, segment: 2))
    }
}
