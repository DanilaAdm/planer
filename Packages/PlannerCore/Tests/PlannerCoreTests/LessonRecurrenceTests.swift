import XCTest
@testable import PlannerCore

final class LessonRecurrenceTests: XCTestCase {
    private let calendar = TestSupport.utcCalendar

    private func repeatingLesson(
        startAt: Date = TestSupport.date(2026, 3, 2, 15),
        durationMinutes: Int = 90,
        isPaid: Bool = true,
        note: String? = "Алгебра"
    ) -> Lesson {
        Lesson(
            studentId: UUID(),
            startAt: startAt,
            durationMinutes: durationMinutes,
            isPaid: isPaid,
            note: note,
            seriesId: UUID()
        )
    }

    func testRepeatsWeeklyFollowsSeriesId() {
        XCTAssertTrue(repeatingLesson().repeatsWeekly)
        XCTAssertFalse(Lesson(studentId: UUID(), startAt: TestSupport.date(2026, 3, 2, 15)).repeatsWeekly)
    }

    /// Отметка «Каждую неделю» обещает занятие на год вперёд.
    func testSeriesCoversAYearAhead() {
        let lesson = repeatingLesson()
        let occurrences = LessonRecurrence.followingOccurrences(of: lesson, calendar: calendar)

        XCTAssertEqual(occurrences.count, 52)
        XCTAssertEqual(occurrences.last?.startAt, TestSupport.date(2027, 3, 1, 15))
    }

    /// Повтор попадает в тот же день недели и то же время: иначе расписание
    /// расползлось бы по неделям.
    func testOccurrencesKeepWeekdayAndTime() {
        let lesson = repeatingLesson(startAt: TestSupport.date(2026, 3, 2, 15, 30))
        let occurrences = LessonRecurrence.followingOccurrences(of: lesson, weeks: 3, calendar: calendar)

        let weekday = calendar.component(.weekday, from: lesson.startAt)
        for occurrence in occurrences {
            XCTAssertEqual(calendar.component(.weekday, from: occurrence.startAt), weekday)
            XCTAssertEqual(calendar.component(.hour, from: occurrence.startAt), 15)
            XCTAssertEqual(calendar.component(.minute, from: occurrence.startAt), 30)
        }
        XCTAssertEqual(occurrences.map(\.startAt), [
            TestSupport.date(2026, 3, 9, 15, 30),
            TestSupport.date(2026, 3, 16, 15, 30),
            TestSupport.date(2026, 3, 23, 15, 30)
        ])
    }

    func testOccurrencesShareSeriesAndLessonDetails() {
        let lesson = repeatingLesson()
        let occurrences = LessonRecurrence.followingOccurrences(of: lesson, weeks: 4, calendar: calendar)

        XCTAssertEqual(Set(occurrences.map(\.seriesId)), [lesson.seriesId])
        XCTAssertEqual(Set(occurrences.map(\.studentId)), [lesson.studentId])
        XCTAssertEqual(Set(occurrences.map(\.durationMinutes)), [lesson.durationMinutes])
        XCTAssertEqual(Set(occurrences.map(\.id)).count, occurrences.count, "У каждого повтора свой id")
        XCTAssertFalse(occurrences.contains { $0.id == lesson.id })
    }

    /// Оплата не переносится на повторы: занятия ещё не прошли, и иначе они
    /// сразу попали бы в заработок и списали абонемент на год вперёд.
    func testOccurrencesAreNotPaid() {
        let occurrences = LessonRecurrence.followingOccurrences(
            of: repeatingLesson(isPaid: true),
            weeks: 5,
            calendar: calendar
        )
        XCTAssertFalse(occurrences.contains { $0.isPaid })
    }

    /// Тема и домашнее задание у каждого занятия свои: повторяется место в
    /// расписании, а не заметка. Иначе она разошлась бы на год вперёд, и её
    /// пришлось бы стирать в каждом занятии вручную.
    func testOccurrencesHaveEmptyNote() {
        let occurrences = LessonRecurrence.followingOccurrences(
            of: repeatingLesson(note: "Уравнения с параметром"),
            weeks: 5,
            calendar: calendar
        )
        XCTAssertFalse(occurrences.isEmpty)
        XCTAssertTrue(occurrences.allSatisfy { $0.note == nil })
    }

    func testLessonWithoutSeriesHasNoOccurrences() {
        let lesson = Lesson(studentId: UUID(), startAt: TestSupport.date(2026, 3, 2, 15))
        XCTAssertTrue(LessonRecurrence.followingOccurrences(of: lesson, calendar: calendar).isEmpty)
    }

    /// Шаг считается календарём, поэтому занятие остаётся в свои 15:00 и после
    /// перевода часов, а не съезжает на час.
    func testTimeSurvivesDaylightSavingChange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.firstWeekday = 2
        // Последнее занятие до перевода часов в Европе — 22 марта 2026.
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 15))!
        let lesson = Lesson(studentId: UUID(), startAt: start, seriesId: UUID())

        let occurrences = LessonRecurrence.followingOccurrences(of: lesson, weeks: 2, calendar: calendar)

        for occurrence in occurrences {
            XCTAssertEqual(calendar.component(.hour, from: occurrence.startAt), 15)
        }
    }
}
