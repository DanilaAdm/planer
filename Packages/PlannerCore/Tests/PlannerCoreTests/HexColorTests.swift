import XCTest
@testable import PlannerCore

final class HexColorTests: XCTestCase {
    func testParseSixDigitHex() {
        let color = HexColor.parse("#FF8000")
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.red ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(color?.green ?? 0, 0.502, accuracy: 0.01)
        XCTAssertEqual(color?.blue ?? 0, 0.0, accuracy: 0.001)
        XCTAssertEqual(color?.alpha ?? 0, 1.0, accuracy: 0.001)
    }

    func testParseWithoutHash() {
        XCTAssertNotNil(HexColor.parse("4E9CFF"))
    }

    func testParseThreeDigitShorthand() {
        let color = HexColor.parse("#0F0")
        XCTAssertEqual(color?.green ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(color?.red ?? 1, 0.0, accuracy: 0.001)
    }

    func testParseEightDigitWithAlpha() {
        let color = HexColor.parse("#00000080")
        XCTAssertEqual(color?.alpha ?? 1, 0.502, accuracy: 0.01)
    }

    func testInvalidStringsReturnNil() {
        XCTAssertNil(HexColor.parse("#ZZZ"))
        XCTAssertNil(HexColor.parse("12345"))
        XCTAssertNil(HexColor.parse(""))
        XCTAssertNil(HexColor.parse("#12"))
    }

    func testRoundTripStringFromColor() {
        let original = "#4E9CFF"
        let color = HexColor.parse(original)!
        XCTAssertEqual(HexColor.string(from: color), original)
    }

    func testNormalizedFixesCase() {
        XCTAssertEqual(HexColor.normalized("#ff8000"), "#FF8000")
    }

    func testNormalizedFallsBackForInvalid() {
        XCTAssertEqual(HexColor.normalized("nonsense"), HexColor.palette[0])
    }

    func testIsValid() {
        XCTAssertTrue(HexColor.isValid("#FFFFFF"))
        XCTAssertFalse(HexColor.isValid("white"))
    }
}
