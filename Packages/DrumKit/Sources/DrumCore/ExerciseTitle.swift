/// Display names for book exercises, whose titles look like "Grade 3 · Nhóm A · Đánh đơn".
public enum ExerciseTitle {
    /// "Grade 3 · Nhóm A · Đánh đơn" → "Grade 3, nhóm A: Đánh đơn", or "Nhóm A: Đánh đơn" when the grade is already on screen.
    public static func short(_ title: String, showingGrade: Bool = true) -> String {
        var parts = title.components(separatedBy: " · ")
        guard parts.count > 1 else { return title }
        var grade: String?
        if parts[0].hasPrefix("Grade ") { grade = parts.removeFirst() }
        let head = parts.count > 1 ? parts.removeFirst() : nil
        let rest = parts.joined(separator: ", ")
        let group = head.map { showingGrade && grade != nil ? $0.prefix(1).lowercased() + $0.dropFirst() : $0 }
        let lead = [showingGrade ? grade : nil, group].compactMap { $0 }.joined(separator: ", ")
        return lead.isEmpty ? rest : "\(lead): \(rest)"
    }
}
