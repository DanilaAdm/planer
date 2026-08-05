import Foundation

/// Логика размещения уроков во времени: пересечения, перенос, длительность.
public enum LessonScheduling {
    /// Минимальная длительность урока (минут).
    public static let minimumDurationMinutes = 15
    /// Шаг изменения времени/длительности (минут).
    public static let stepMinutes = 15
    /// Максимальная длительность урока (минут).
    public static let maximumDurationMinutes = 8 * 60

    /// Пересекаются ли два урока по времени (полуинтервалы [start, end)).
    public static func overlaps(_ a: Lesson, _ b: Lesson) -> Bool {
        guard a.id != b.id else { return false }
        return a.startAt < b.endAt && b.startAt < a.endAt
    }

    /// Есть ли у урока конфликт с любым из `others` (репетитор не может вести
    /// два урока одновременно).
    public static func hasConflict(_ lesson: Lesson, with others: [Lesson]) -> Bool {
        others.contains { overlaps(lesson, $0) }
    }

    /// Перенести урок на новое время начала.
    public static func move(_ lesson: Lesson, to newStart: Date) -> Lesson {
        var copy = lesson
        copy.startAt = newStart
        return copy
    }

    /// Сдвинуть урок на заданное число минут.
    public static func shift(_ lesson: Lesson, byMinutes minutes: Int) -> Lesson {
        move(lesson, to: lesson.startAt.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    /// Изменить длительность урока с ограничением диапазона.
    public static func resize(_ lesson: Lesson, toDurationMinutes minutes: Int) -> Lesson {
        var copy = lesson
        copy.durationMinutes = clampDuration(minutes)
        return copy
    }

    /// Ограничить длительность допустимым диапазоном.
    public static func clampDuration(_ minutes: Int) -> Int {
        min(maximumDurationMinutes, max(minimumDurationMinutes, minutes))
    }

    /// Округлить длительность к ближайшему шагу `stepMinutes`.
    public static func snappedDuration(_ minutes: Int) -> Int {
        let snapped = Int((Double(minutes) / Double(stepMinutes)).rounded()) * stepMinutes
        return clampDuration(snapped)
    }

    /// Округлить дату к ближайшему шагу `stepMinutes` в пределах суток.
    public static func snappedStart(_ date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let minutesFromMidnight = Int(date.timeIntervalSince(startOfDay) / 60)
        let snapped = Int((Double(minutesFromMidnight) / Double(stepMinutes)).rounded()) * stepMinutes
        return startOfDay.addingTimeInterval(TimeInterval(snapped * 60))
    }
}
