import Foundation

/// Полуинтервал дат [start, end).
public struct DateRange: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

/// Утилиты для вычисления диапазонов календаря (месяц/неделя/день).
public enum CalendarRange {

    /// Диапазон суток, содержащих `date`.
    public static func day(containing date: Date, calendar: Calendar = .current) -> DateRange {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DateRange(start: start, end: end)
    }

    /// Диапазон недели, содержащей `date` (с учётом firstWeekday календаря).
    public static func week(containing date: Date, calendar: Calendar = .current) -> DateRange {
        let startOfDay = calendar.startOfDay(for: date)
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: startOfDay) else {
            return day(containing: date, calendar: calendar)
        }
        return DateRange(start: interval.start, end: interval.end)
    }

    /// Диапазон месяца, содержащего `date`.
    public static func month(containing date: Date, calendar: Calendar = .current) -> DateRange {
        let startOfDay = calendar.startOfDay(for: date)
        guard let interval = calendar.dateInterval(of: .month, for: startOfDay) else {
            return day(containing: date, calendar: calendar)
        }
        return DateRange(start: interval.start, end: interval.end)
    }

    /// Массив из 7 дат-начал суток для недели, содержащей `date`.
    public static func weekDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let range = week(containing: date, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: range.start) }
    }

    /// Отфильтровать уроки, начинающиеся внутри диапазона.
    public static func lessons(_ lessons: [Lesson], in range: DateRange) -> [Lesson] {
        lessons.filter { range.contains($0.startAt) }
    }

    /// Отфильтровать личные задачи, запланированные внутри диапазона.
    public static func tasks(_ tasks: [PersonalTask], in range: DateRange) -> [PersonalTask] {
        tasks.filter { range.contains($0.scheduledAt) }
    }

    /// Отфильтровать заметки, относящиеся к неделе, которая начинается `weekStart`.
    ///
    /// Сравниваются именно недели, а не сами даты: заметка, заведённая в другом
    /// часовом поясе, всё равно относится к своей календарной неделе.
    public static func weekNotes(
        _ notes: [WeekNote],
        weekStart: Date,
        calendar: Calendar = .current
    ) -> [WeekNote] {
        let range = week(containing: weekStart, calendar: calendar)
        return notes.filter { range.contains(week(containing: $0.weekStart, calendar: calendar).start) }
    }
}
