import SwiftUI
import PlannerCore

/// Чипы состояния ученика: формат работы и — если абонемент на исходе — метка
/// подсветки. На узких экранах метка сжимается до одной иконки, иначе чип
/// формата остался бы без места и схлопнулся.
struct StudentStatusChips: View {
    let student: Student

    var body: some View {
        if let title = student.paidPackageEndingTitle {
            ViewThatFits(in: .horizontal) {
                chips(badgeTitle: title)
                chips(badgeTitle: nil)
            }
        } else {
            formatChip
        }
    }

    private func chips(badgeTitle: String?) -> some View {
        HStack(spacing: 5) {
            formatChip
            LastLessonBadge(title: badgeTitle)
        }
        .fixedSize()
    }

    private var formatChip: some View {
        StatusChip(
            text: student.workFormat.localizedTitle,
            kind: student.workFormat == .subscription ? .accent : .neutral
        )
    }
}
