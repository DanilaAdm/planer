import XCTest
@testable import PlannerCore

final class EarningsCalculatorTests: XCTestCase {
    let cal = TestSupport.utcCalendar

    func testPostpayEarningsCountsOnlyPaidLessons() {
        // Заработок считается по отметке «Занятие оплачено» и для постоплаты тоже.
        let student = TestSupport.makeStudent(price: 1000, format: .postpay)
        let lessons = [
            Lesson(studentId: student.id, startAt: TestSupport.date(2026, 3, 2, 10), isPaid: false),
            Lesson(studentId: student.id, startAt: TestSupport.date(2026, 3, 10, 12), isPaid: true),
            Lesson(studentId: student.id, startAt: TestSupport.date(2026, 4, 1, 12), isPaid: true) // другой месяц
        ]
        let result = EarningsCalculator.earnings(
            for: student, lessons: lessons, month: 3, year: 2026, calendar: cal
        )
        XCTAssertEqual(result.lessonsCount, 2)
        XCTAssertEqual(result.paidLessonsCount, 1)
        XCTAssertEqual(result.amount, Decimal(1000))
    }

    func testSubscriptionEarningsCountsOnlyPaidLessons() {
        let student = TestSupport.makeStudent(price: 800, format: .subscription)
        let lessons = [
            Lesson(studentId: student.id, startAt: TestSupport.date(2026, 3, 2, 10), isPaid: true),
            Lesson(studentId: student.id, startAt: TestSupport.date(2026, 3, 5, 10), isPaid: false),
            Lesson(studentId: student.id, startAt: TestSupport.date(2026, 3, 9, 10), isPaid: true)
        ]
        let result = EarningsCalculator.earnings(
            for: student, lessons: lessons, month: 3, year: 2026, calendar: cal
        )
        XCTAssertEqual(result.lessonsCount, 3)
        XCTAssertEqual(result.paidLessonsCount, 2)
        XCTAssertEqual(result.amount, Decimal(1600))
    }

    func testEarningsIgnoreOtherStudents() {
        let a = TestSupport.makeStudent(name: "A", price: 500)
        let b = TestSupport.makeStudent(name: "B", price: 500)
        let lessons = [
            Lesson(studentId: a.id, startAt: TestSupport.date(2026, 3, 2, 10), isPaid: true),
            Lesson(studentId: b.id, startAt: TestSupport.date(2026, 3, 3, 10), isPaid: true)
        ]
        let result = EarningsCalculator.earnings(for: a, lessons: lessons, month: 3, year: 2026, calendar: cal)
        XCTAssertEqual(result.lessonsCount, 1)
        XCTAssertEqual(result.amount, Decimal(500))
    }

    func testTotalEarningsAcrossStudents() {
        let a = TestSupport.makeStudent(name: "A", price: 1000, format: .postpay)
        let b = TestSupport.makeStudent(name: "B", price: 2000, format: .subscription)
        let lessons = [
            Lesson(studentId: a.id, startAt: TestSupport.date(2026, 3, 2, 10), isPaid: true),
            Lesson(studentId: a.id, startAt: TestSupport.date(2026, 3, 4, 10), isPaid: true),
            Lesson(studentId: b.id, startAt: TestSupport.date(2026, 3, 6, 10), isPaid: true),
            Lesson(studentId: b.id, startAt: TestSupport.date(2026, 3, 8, 10), isPaid: false)
        ]
        let total = EarningsCalculator.totalEarnings(
            students: [a, b], lessons: lessons, month: 3, year: 2026, calendar: cal
        )
        // A: 2 оплаченных * 1000 = 2000, B: 1 оплаченный * 2000 = 2000
        XCTAssertEqual(total, Decimal(4000))
    }

    func testEarningsByStudentSortedDescending() {
        let a = TestSupport.makeStudent(name: "A", price: 500, format: .postpay)
        let b = TestSupport.makeStudent(name: "B", price: 3000, format: .postpay)
        let lessons = [
            Lesson(studentId: a.id, startAt: TestSupport.date(2026, 3, 2, 10), isPaid: true),
            Lesson(studentId: b.id, startAt: TestSupport.date(2026, 3, 6, 10), isPaid: true)
        ]
        let sorted = EarningsCalculator.earningsByStudent(
            students: [a, b], lessons: lessons, month: 3, year: 2026, calendar: cal
        )
        XCTAssertEqual(sorted.first?.student.id, b.id)
        XCTAssertEqual(sorted.first?.amount, Decimal(3000))
    }

    func testEmptyMonthYieldsZero() {
        let student = TestSupport.makeStudent(price: 1000)
        let result = EarningsCalculator.earnings(for: student, lessons: [], month: 3, year: 2026, calendar: cal)
        XCTAssertEqual(result.amount, Decimal(0))
        XCTAssertEqual(result.lessonsCount, 0)
    }
}
