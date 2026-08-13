import Foundation

/// Еженедельное повторение занятия.
///
/// Повторы — обычные занятия расписания с общим `seriesId`, а не правило,
/// раскрываемое при показе. Так каждый повтор можно оплатить, перенести или
/// отменить по отдельности, и весь остальной планер (заработок, абонементы,
/// офлайн-кэш) работает с ними без исключений.
public enum LessonRecurrence {
    /// Насколько вперёд раскрывается повторение: год.
    public static let horizonWeeks = 52

    /// Повторы, которые идут за `lesson` с шагом в неделю.
    ///
    /// Повторяется само место в расписании — ученик, день, время и длительность.
    /// Заметка и отметка «занятие оплачено» на повторы не переносятся: тема и
    /// домашнее задание у каждого занятия свои, а будущие занятия ещё не прошли.
    /// Шаг считается календарём, а не сутками в секундах, — иначе перевод часов
    /// сдвинул бы время занятия.
    public static func followingOccurrences(
        of lesson: Lesson,
        weeks: Int = horizonWeeks,
        calendar: Calendar = .current
    ) -> [Lesson] {
        guard let seriesId = lesson.seriesId, weeks > 0 else { return [] }
        return (1...weeks).compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset, to: lesson.startAt) else {
                return nil
            }
            return Lesson(
                studentId: lesson.studentId,
                startAt: start,
                durationMinutes: lesson.durationMinutes,
                isPaid: false,
                note: nil,
                seriesId: seriesId,
                createdAt: lesson.createdAt
            )
        }
    }
}
