import XCTest
@testable import PlannerCore

final class PaidLessonsTests: XCTestCase {
    func testConsumeIncrementsUsedWithinBounds() {
        let student = TestSupport.makeStudent(paidTotal: 4, used: 1)
        let updated = PaidLessons.consumeOne(student)
        XCTAssertEqual(updated.lessonsUsed, 2)
        XCTAssertEqual(updated.paidLessonsRemaining, 2)
        XCTAssertEqual(updated.paidLessonsIndicator, "2/4")
    }

    func testConsumeDoesNotExceedTotal() {
        let student = TestSupport.makeStudent(paidTotal: 4, used: 4)
        let updated = PaidLessons.consumeOne(student)
        XCTAssertEqual(updated.lessonsUsed, 4)
        XCTAssertFalse(PaidLessons.canConsume(updated))
    }

    func testConsumeWithZeroTotalStaysZero() {
        let student = TestSupport.makeStudent(paidTotal: 0, used: 0)
        let updated = PaidLessons.consumeOne(student)
        XCTAssertEqual(updated.lessonsUsed, 0)
        XCTAssertEqual(updated.paidLessonsIndicator, "0/0")
    }

    func testRestoreDecrementsNotBelowZero() {
        let student = TestSupport.makeStudent(paidTotal: 4, used: 0)
        let updated = PaidLessons.restoreOne(student)
        XCTAssertEqual(updated.lessonsUsed, 0)
    }

    func testRestoreDecrements() {
        let student = TestSupport.makeStudent(paidTotal: 4, used: 3)
        let updated = PaidLessons.restoreOne(student)
        XCTAssertEqual(updated.lessonsUsed, 2)
    }

    func testAddPaidLessonsIncreasesTotal() {
        let student = TestSupport.makeStudent(paidTotal: 4, used: 4)
        let updated = PaidLessons.addPaidLessons(student, count: 4)
        XCTAssertEqual(updated.paidLessonsTotal, 8)
        XCTAssertTrue(PaidLessons.canConsume(updated))
    }

    func testCanConsumeReflectsRemaining() {
        XCTAssertTrue(PaidLessons.canConsume(TestSupport.makeStudent(paidTotal: 2, used: 1)))
        XCTAssertFalse(PaidLessons.canConsume(TestSupport.makeStudent(paidTotal: 2, used: 2)))
    }

    // MARK: - Подсветка «абонемент на исходе»

    func testPackageIsNotEndingWithTwoLessonsLeft() {
        let student = TestSupport.makeStudent(format: .subscription, paidTotal: 4, used: 2)
        XCTAssertFalse(student.isPaidPackageEnding)
        XCTAssertNil(student.paidPackageEndingTitle)
    }

    func testPackageIsEndingWithOneLessonLeft() {
        let student = TestSupport.makeStudent(format: .subscription, paidTotal: 4, used: 3)
        XCTAssertTrue(student.isPaidPackageEnding)
        XCTAssertEqual(student.paidPackageEndingTitle, "Последний урок")
    }

    func testPackageIsEndingWithoutLessonsLeft() {
        let spent = TestSupport.makeStudent(format: .subscription, paidTotal: 4, used: 4)
        XCTAssertTrue(spent.isPaidPackageEnding)
        XCTAssertEqual(spent.paidPackageEndingTitle, "Нет оплаченных")

        // Абонемент ещё не заведён (0/0) — тоже подсвечиваем.
        let fresh = TestSupport.makeStudent(format: .subscription, paidTotal: 0, used: 0)
        XCTAssertTrue(fresh.isPaidPackageEnding)
        XCTAssertEqual(fresh.paidPackageEndingTitle, "Нет оплаченных")
    }

    func testPostpayStudentIsNeverEnding() {
        XCTAssertFalse(TestSupport.makeStudent(format: .postpay, paidTotal: 0, used: 0).isPaidPackageEnding)
        XCTAssertFalse(TestSupport.makeStudent(format: .postpay, paidTotal: 4, used: 4).isPaidPackageEnding)
    }

    func testConsumingLastButOneLessonTurnsOnHighlight() {
        let student = TestSupport.makeStudent(format: .subscription, paidTotal: 4, used: 2)
        let updated = PaidLessons.consumeOne(student)
        XCTAssertEqual(updated.paidLessonsIndicator, "3/4")
        XCTAssertTrue(updated.isPaidPackageEnding)
    }
}
