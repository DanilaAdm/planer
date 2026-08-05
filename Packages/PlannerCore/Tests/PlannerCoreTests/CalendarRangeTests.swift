import XCTest
@testable import PlannerCore

final class CalendarRangeTests: XCTestCase {
    let cal = TestSupport.utcCalendar

    func testDayRange() {
        let range = CalendarRange.day(containing: TestSupport.date(2026, 3, 2, 15, 30), calendar: cal)
        XCTAssertEqual(range.start, TestSupport.date(2026, 3, 2, 0, 0))
        XCTAssertEqual(range.end, TestSupport.date(2026, 3, 3, 0, 0))
    }

    func testWeekRangeStartsMonday() {
        // 2026-03-04 — среда; неделя должна начинаться в понедельник 2026-03-02.
        let range = CalendarRange.week(containing: TestSupport.date(2026, 3, 4, 12), calendar: cal)
        XCTAssertEqual(range.start, TestSupport.date(2026, 3, 2, 0, 0))
        XCTAssertEqual(range.end, TestSupport.date(2026, 3, 9, 0, 0))
    }

    func testWeekDaysReturnsSevenDays() {
        let days = CalendarRange.weekDays(containing: TestSupport.date(2026, 3, 4), calendar: cal)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first, TestSupport.date(2026, 3, 2, 0, 0))
        XCTAssertEqual(days.last, TestSupport.date(2026, 3, 8, 0, 0))
    }

    func testMonthRange() {
        let range = CalendarRange.month(containing: TestSupport.date(2026, 3, 15), calendar: cal)
        XCTAssertEqual(range.start, TestSupport.date(2026, 3, 1, 0, 0))
        XCTAssertEqual(range.end, TestSupport.date(2026, 4, 1, 0, 0))
    }

    func testContainsIsHalfOpen() {
        let range = DateRange(start: TestSupport.date(2026, 3, 2), end: TestSupport.date(2026, 3, 3))
        XCTAssertTrue(range.contains(TestSupport.date(2026, 3, 2, 0, 0)))
        XCTAssertFalse(range.contains(TestSupport.date(2026, 3, 3, 0, 0)))
    }

    func testLessonsInRangeFilters() {
        let sid = UUID()
        let lessons = [
            Lesson(studentId: sid, startAt: TestSupport.date(2026, 3, 2, 10)),
            Lesson(studentId: sid, startAt: TestSupport.date(2026, 3, 5, 10))
        ]
        let range = CalendarRange.day(containing: TestSupport.date(2026, 3, 2), calendar: cal)
        let filtered = CalendarRange.lessons(lessons, in: range)
        XCTAssertEqual(filtered.count, 1)
    }
}
