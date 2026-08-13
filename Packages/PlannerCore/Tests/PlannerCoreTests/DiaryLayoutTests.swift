import XCTest
@testable import PlannerCore

final class DiaryLayoutTests: XCTestCase {

    // MARK: - Свободный слот

    func testEmptyBlockKeepsMinimumRows() {
        XCTAssertEqual(DiaryLayout.slots(filled: 0), DiaryLayout.minRows)
    }

    /// Ключевое правило: под последней записью всегда есть свободная строка,
    /// поэтому записи дня не выходят за границу блока.
    func testFilledBlockAlwaysHasOneFreeSlot() {
        XCTAssertEqual(DiaryLayout.slots(filled: 4), 5)
        XCTAssertEqual(DiaryLayout.slots(filled: 10), 11)
    }

    func testShortBlockIsNotSmallerThanMinimum() {
        XCTAssertEqual(DiaryLayout.slots(filled: 1), DiaryLayout.minRows)
        XCTAssertEqual(DiaryLayout.slots(filled: 3), DiaryLayout.minRows)
    }

    // MARK: - Симметрия разворота

    /// Понедельник стоит напротив четверга: разросшийся четверг обязан поднять
    /// и понедельник, иначе строки страниц разъезжаются.
    func testPairedBlocksGetTheSameNumberOfSlots() {
        let counts = DiaryLayout.rowCounts(
            dayEntryCounts: [0, 0, 0, 10, 0, 0, 0],
            noteCount: 0,
            paired: true
        )
        XCTAssertEqual(counts.days[0], 11, "Понедельник не вырос вместе с четвергом")
        XCTAssertEqual(counts.days[3], 11)
        XCTAssertEqual(counts.days[1], counts.days[4])
        XCTAssertEqual(counts.days[2], counts.days[5])
    }

    /// Блок заметок стоит напротив воскресенья и растёт вместе с ним.
    func testNotesBlockMatchesSunday() {
        let bySunday = DiaryLayout.rowCounts(
            dayEntryCounts: [0, 0, 0, 0, 0, 0, 6],
            noteCount: 0,
            paired: true
        )
        XCTAssertEqual(bySunday.notes, 7)
        XCTAssertEqual(bySunday.days[6], 7)

        let byNotes = DiaryLayout.rowCounts(
            dayEntryCounts: [0, 0, 0, 0, 0, 0, 0],
            noteCount: 8,
            paired: true
        )
        XCTAssertEqual(byNotes.days[6], 9, "Воскресенье не выровнялось по блоку заметок")
        XCTAssertEqual(byNotes.notes, 9)
    }

    /// Растут только парные блоки: остальные дни не должны раздуваться заодно.
    func testOnlyThePairGrows() {
        let counts = DiaryLayout.rowCounts(
            dayEntryCounts: [0, 0, 0, 10, 0, 0, 0],
            noteCount: 0,
            paired: true
        )
        XCTAssertEqual(counts.days[1], DiaryLayout.minRows)
        XCTAssertEqual(counts.days[2], DiaryLayout.minRows)
        XCTAssertEqual(counts.notes, DiaryLayout.minRows)
    }

    /// На узком экране страница одна, выравнивать нечего.
    func testSinglePageKeepsOwnHeights() {
        let counts = DiaryLayout.rowCounts(
            dayEntryCounts: [0, 0, 0, 10, 0, 0, 0],
            noteCount: 0,
            paired: false
        )
        XCTAssertEqual(counts.days[0], DiaryLayout.minRows)
        XCTAssertEqual(counts.days[3], 11)
    }

    /// Неполный список дней (например, из тестового или будущего вызова) не должен
    /// приводить к обращению за пределы массива.
    func testUnexpectedDayCountFallsBackToOwnHeights() {
        let counts = DiaryLayout.rowCounts(dayEntryCounts: [5, 0], noteCount: 0, paired: true)
        XCTAssertEqual(counts.days, [6, DiaryLayout.minRows])
        XCTAssertEqual(counts.notes, DiaryLayout.minRows)
    }
}
