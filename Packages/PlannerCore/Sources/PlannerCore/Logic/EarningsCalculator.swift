import Foundation

/// Заработок за месяц по одному ученику.
public struct StudentEarnings: Equatable, Sendable {
    public let student: Student
    public let lessonsCount: Int
    public let paidLessonsCount: Int
    public let amount: Decimal

    public init(student: Student, lessonsCount: Int, paidLessonsCount: Int, amount: Decimal) {
        self.student = student
        self.lessonsCount = lessonsCount
        self.paidLessonsCount = paidLessonsCount
        self.amount = amount
    }
}

/// Расчёт заработка за месяц.
///
/// Заработок считается по отметке «Занятие оплачено» (`isPaid == true`)
/// независимо от формата работы (постоплата/абонемент):
/// заработок = (число оплаченных уроков в месяце) × цена урока.
public enum EarningsCalculator {

    /// Уроки конкретного ученика в заданном месяце.
    public static func lessons(
        for student: Student,
        in lessons: [Lesson],
        month: Int,
        year: Int,
        calendar: Calendar = .current
    ) -> [Lesson] {
        lessons.filter { lesson in
            guard lesson.studentId == student.id else { return false }
            let comps = calendar.dateComponents([.year, .month], from: lesson.startAt)
            return comps.year == year && comps.month == month
        }
    }

    /// Заработок по ученику за месяц.
    public static func earnings(
        for student: Student,
        lessons allLessons: [Lesson],
        month: Int,
        year: Int,
        calendar: Calendar = .current
    ) -> StudentEarnings {
        let monthLessons = lessons(for: student, in: allLessons, month: month, year: year, calendar: calendar)
        let paidCount = monthLessons.filter { $0.isPaid }.count

        // Заработок считается по отметке «Занятие оплачено» независимо от формата работы.
        let amount = student.pricePerLesson * Decimal(paidCount)
        return StudentEarnings(
            student: student,
            lessonsCount: monthLessons.count,
            paidLessonsCount: paidCount,
            amount: amount
        )
    }

    /// Заработок по всем ученикам за месяц (отсортировано по убыванию суммы).
    public static func earningsByStudent(
        students: [Student],
        lessons: [Lesson],
        month: Int,
        year: Int,
        calendar: Calendar = .current
    ) -> [StudentEarnings] {
        students
            .map { earnings(for: $0, lessons: lessons, month: month, year: year, calendar: calendar) }
            .sorted { $0.amount > $1.amount }
    }

    /// Итоговый заработок за месяц по всем ученикам.
    public static func totalEarnings(
        students: [Student],
        lessons: [Lesson],
        month: Int,
        year: Int,
        calendar: Calendar = .current
    ) -> Decimal {
        earningsByStudent(students: students, lessons: lessons, month: month, year: year, calendar: calendar)
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
}
