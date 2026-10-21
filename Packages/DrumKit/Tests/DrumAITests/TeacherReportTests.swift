import Foundation
import Testing
@testable import DrumAI

private func item(id: String? = "L1-singles8", dsl: String? = nil, bpm: Int = 70, minutes: Int = 5) -> PlannedItem {
    PlannedItem(exerciseId: id, newExerciseDSL: dsl, bpm: bpm, minutes: minutes, focus: "f")
}

private func report(_ items: [PlannedItem]) -> TeacherReport {
    TeacherReport(summary: "s", progress: [], fixFirst: ["a", "b", "c", "d"], likelyCauses: [],
                  weekPlan: [DayPlan(day: 1, warmup: items, main: [], fun: [])], resources: [], nextCheckpoint: "n")
}

@Test func sanitizeDropsBadItems() {
    let good = "title: A\ntime: 4/4\ngrid: 1\nSN: xxxx"
    let r = report([item(), item(id: "nope"), item(id: nil, dsl: good), item(id: nil, dsl: "garbage"), item(bpm: 999), item(minutes: 0)])
        .sanitized(knownExerciseIds: ["L1-singles8"])
    #expect(r.weekPlan[0].warmup.count == 2)
    #expect(r.fixFirst.count == 3)
}

@Test func sanitizeDropsBadDays() {
    let r = TeacherReport(summary: "s", progress: [], fixFirst: [], likelyCauses: [],
                          weekPlan: [DayPlan(day: 0, warmup: [item()], main: [], fun: []), DayPlan(day: 9, warmup: [], main: [], fun: [])],
                          resources: [], nextCheckpoint: "n").sanitized(knownExerciseIds: ["L1-singles8"])
    #expect(r.weekPlan.isEmpty)
}

@Test func pageIdFromNotionLink() {
    #expect(NotionClient.pageId(fromLink: "https://www.notion.so/DrumCoach-1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d?pvs=4") == "1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d")
    #expect(NotionClient.pageId(fromLink: "1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d") == "1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d")
    #expect(NotionClient.pageId(fromLink: "https://example.com") == nil)
}
