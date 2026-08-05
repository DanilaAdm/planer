import Foundation
@testable import PlannerCore

/// Общие помощники для тестов.
enum TestSupport {
    /// Григорианский календарь в UTC для детерминированных дат.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2 // понедельник
        return calendar
    }

    /// Собрать дату из компонентов в UTC.
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return utcCalendar.date(from: comps)!
    }

    static func makeStudent(
        name: String = "Иван",
        price: Decimal = 1000,
        format: WorkFormat = .postpay,
        paidTotal: Int = 0,
        used: Int = 0
    ) -> Student {
        Student(
            name: name,
            colorHex: "#4E9CFF",
            pricePerLesson: price,
            workFormat: format,
            paidLessonsTotal: paidTotal,
            lessonsUsed: used
        )
    }
}
