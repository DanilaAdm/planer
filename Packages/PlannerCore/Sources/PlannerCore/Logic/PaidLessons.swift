import Foundation

/// Логика управления счётчиком оплаченных уроков ученика.
public enum PaidLessons {
    /// Списать один оплаченный урок (кнопка "−").
    /// Увеличивает `lessonsUsed`, не превышая `paidLessonsTotal` и не опускаясь ниже 0.
    /// - Returns: обновлённая копия ученика.
    public static func consumeOne(_ student: Student) -> Student {
        var copy = student
        copy.lessonsUsed = min(student.paidLessonsTotal, student.lessonsUsed + 1)
        copy.lessonsUsed = max(0, copy.lessonsUsed)
        return copy
    }

    /// Вернуть один оплаченный урок (отмена списания).
    public static func restoreOne(_ student: Student) -> Student {
        var copy = student
        copy.lessonsUsed = max(0, student.lessonsUsed - 1)
        return copy
    }

    /// Добавить оплаченные уроки в пакет (например, при новой оплате абонемента).
    public static func addPaidLessons(_ student: Student, count: Int) -> Student {
        guard count > 0 else { return student }
        var copy = student
        copy.paidLessonsTotal = max(0, student.paidLessonsTotal + count)
        return copy
    }

    /// Можно ли ещё списать оплаченный урок.
    public static func canConsume(_ student: Student) -> Bool {
        student.lessonsUsed < student.paidLessonsTotal
    }
}
