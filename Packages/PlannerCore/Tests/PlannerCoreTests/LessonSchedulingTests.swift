import XCTest
@testable import PlannerCore

final class LessonSchedulingTests: XCTestCase {
    let studentId = UUID()

    func testOverlapsWhenIntervalsIntersect() {
        let a = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 10, 0), durationMinutes: 60)
        let b = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 10, 30), durationMinutes: 60)
        XCTAssertTrue(LessonScheduling.overlaps(a, b))
    }

    func testDoesNotOverlapWhenAdjacent() {
        let a = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 10, 0), durationMinutes: 60)
        let b = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 11, 0), durationMinutes: 60)
        XCTAssertFalse(LessonScheduling.overlaps(a, b))
    }

    func testSameLessonDoesNotOverlapItself() {
        let a = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 10, 0), durationMinutes: 60)
        XCTAssertFalse(LessonScheduling.overlaps(a, a))
    }

    func testHasConflictDetectsOverlap() {
        let existing = [
            Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 9, 0), durationMinutes: 60),
            Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 12, 0), durationMinutes: 60)
        ]
        let candidate = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 9, 30), durationMinutes: 60)
        XCTAssertTrue(LessonScheduling.hasConflict(candidate, with: existing))
    }

    func testHasNoConflictWhenFree() {
        let existing = [
            Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 9, 0), durationMinutes: 60)
        ]
        let candidate = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 11, 0), durationMinutes: 60)
        XCTAssertFalse(LessonScheduling.hasConflict(candidate, with: existing))
    }

    func testMoveChangesStart() {
        let lesson = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 10, 0), durationMinutes: 60)
        let newStart = TestSupport.date(2026, 3, 2, 14, 0)
        let moved = LessonScheduling.move(lesson, to: newStart)
        XCTAssertEqual(moved.startAt, newStart)
        XCTAssertEqual(moved.durationMinutes, 60)
    }

    func testShiftByMinutes() {
        let lesson = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 10, 0), durationMinutes: 60)
        let shifted = LessonScheduling.shift(lesson, byMinutes: 30)
        XCTAssertEqual(shifted.startAt, TestSupport.date(2026, 3, 2, 10, 30))
    }

    func testResizeClampsToMinimum() {
        let lesson = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 10, 0), durationMinutes: 60)
        let resized = LessonScheduling.resize(lesson, toDurationMinutes: 5)
        XCTAssertEqual(resized.durationMinutes, LessonScheduling.minimumDurationMinutes)
    }

    func testResizeClampsToMaximum() {
        let lesson = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 10, 0), durationMinutes: 60)
        let resized = LessonScheduling.resize(lesson, toDurationMinutes: 10_000)
        XCTAssertEqual(resized.durationMinutes, LessonScheduling.maximumDurationMinutes)
    }

    func testSnappedDurationRoundsToStep() {
        XCTAssertEqual(LessonScheduling.snappedDuration(52), 45)
        XCTAssertEqual(LessonScheduling.snappedDuration(53), 60)
    }

    func testSnappedStartRoundsToStep() {
        let date = TestSupport.date(2026, 3, 2, 10, 7)
        let snapped = LessonScheduling.snappedStart(date, calendar: TestSupport.utcCalendar)
        XCTAssertEqual(snapped, TestSupport.date(2026, 3, 2, 10, 0))
    }

    func testLessonEndComputedFromDuration() {
        let lesson = Lesson(studentId: studentId, startAt: TestSupport.date(2026, 3, 2, 10, 0), durationMinutes: 90)
        XCTAssertEqual(lesson.endAt, TestSupport.date(2026, 3, 2, 11, 30))
    }
}
