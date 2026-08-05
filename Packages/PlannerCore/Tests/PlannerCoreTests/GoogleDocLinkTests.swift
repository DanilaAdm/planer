import XCTest
@testable import PlannerCore

final class GoogleDocLinkTests: XCTestCase {
    /// Реальная ссылка на документ ученицы Ксюши (доступ по ссылке).
    private let ksyushaURL = URL(
        string: "https://docs.google.com/document/d/1GJCIgRcxw_RF4ku98-7-uQwNv4I6Y_Gn8SSJQ9aYCN0/edit?tab=t.0"
    )!

    func testParsesRealDocumentLink() {
        let link = GoogleDocLink(ksyushaURL)
        XCTAssertEqual(link?.documentId, "1GJCIgRcxw_RF4ku98-7-uQwNv4I6Y_Gn8SSJQ9aYCN0")
        XCTAssertEqual(link?.kind, .document)
        XCTAssertEqual(link?.tab, "t.0")
    }

    func testReaderURLUsesMobileBasicAndKeepsTab() {
        XCTAssertEqual(
            GoogleDocLink(ksyushaURL)?.readerURL.absoluteString,
            "https://docs.google.com/document/d/1GJCIgRcxw_RF4ku98-7-uQwNv4I6Y_Gn8SSJQ9aYCN0/mobilebasic?tab=t.0"
        )
    }

    func testFullViewURLUsesPreview() {
        XCTAssertEqual(
            GoogleDocLink(ksyushaURL)?.fullViewURL.absoluteString,
            "https://docs.google.com/document/d/1GJCIgRcxw_RF4ku98-7-uQwNv4I6Y_Gn8SSJQ9aYCN0/preview?tab=t.0"
        )
    }

    func testBrowserURLKeepsOriginalLink() {
        XCTAssertEqual(GoogleDocLink(ksyushaURL)?.browserURL, ksyushaURL)
    }

    func testDocumentWithoutTabHasNoQuery() {
        let url = URL(string: "https://docs.google.com/document/d/abc123/edit")!
        XCTAssertNil(GoogleDocLink(url)?.tab)
        XCTAssertEqual(
            GoogleDocLink(url)?.readerURL.absoluteString,
            "https://docs.google.com/document/d/abc123/mobilebasic"
        )
    }

    func testAccountNumberInPathIsIgnored() {
        let url = URL(string: "https://docs.google.com/document/u/0/d/abc123/edit")!
        XCTAssertEqual(GoogleDocLink(url)?.documentId, "abc123")
        XCTAssertEqual(
            GoogleDocLink(url)?.readerURL.absoluteString,
            "https://docs.google.com/document/d/abc123/mobilebasic"
        )
    }

    func testSpreadsheetUsesHtmlViewAndKeepsSheetAnchor() {
        let url = URL(string: "https://docs.google.com/spreadsheets/d/sheet1/edit#gid=42")!
        let link = GoogleDocLink(url)
        XCTAssertEqual(link?.kind, .spreadsheet)
        XCTAssertEqual(
            link?.readerURL.absoluteString,
            "https://docs.google.com/spreadsheets/d/sheet1/htmlview#gid=42"
        )
    }

    func testPresentationUsesPreview() {
        let url = URL(string: "https://docs.google.com/presentation/d/slides1/edit")!
        XCTAssertEqual(
            GoogleDocLink(url)?.readerURL.absoluteString,
            "https://docs.google.com/presentation/d/slides1/preview"
        )
    }

    func testUnknownGoogleServiceKeepsOriginalURL() {
        let url = URL(string: "https://docs.google.com/forms/d/form1/viewform")!
        let link = GoogleDocLink(url)
        XCTAssertEqual(link?.kind, .other)
        XCTAssertEqual(link?.readerURL, url)
        XCTAssertEqual(link?.fullViewURL, url)
    }

    func testNonGoogleAndMalformedLinksAreRejected() {
        XCTAssertNil(GoogleDocLink(URL(string: "https://example.com/document/d/abc/edit")!))
        XCTAssertNil(GoogleDocLink(URL(string: "https://docs.google.com/document/d/")!))
        XCTAssertNil(GoogleDocLink(URL(string: "https://docs.google.com/")!))
    }

    func testPublishedDocumentIsNotRewritten() {
        // У опубликованных документов (/d/e/<id>/pub) нет облегчённого режима чтения.
        let url = URL(string: "https://docs.google.com/document/d/e/2PACX-abc/pub")!
        XCTAssertNil(GoogleDocLink(url))
        XCTAssertEqual(GoogleDocLink.readerURL(for: url), url)
    }

    func testReaderURLForAnyLink() {
        XCTAssertEqual(
            GoogleDocLink.readerURL(for: ksyushaURL).absoluteString,
            "https://docs.google.com/document/d/1GJCIgRcxw_RF4ku98-7-uQwNv4I6Y_Gn8SSJQ9aYCN0/mobilebasic?tab=t.0"
        )
        let other = URL(string: "https://example.com/notes")!
        XCTAssertEqual(GoogleDocLink.readerURL(for: other), other)
    }

    func testNormalizedAddsSchemeAndTrimsWhitespace() {
        XCTAssertEqual(
            GoogleDocLink.normalized("  docs.google.com/document/d/abc123/edit  ")?.absoluteString,
            "https://docs.google.com/document/d/abc123/edit"
        )
    }

    func testNormalizedKeepsExistingScheme() {
        XCTAssertEqual(
            GoogleDocLink.normalized("http://docs.google.com/document/d/abc/edit")?.absoluteString,
            "http://docs.google.com/document/d/abc/edit"
        )
    }

    func testNormalizedRejectsEmptyAndInvalidInput() {
        XCTAssertNil(GoogleDocLink.normalized(""))
        XCTAssertNil(GoogleDocLink.normalized("   "))
        XCTAssertNil(GoogleDocLink.normalized("просто текст"))
        XCTAssertNil(GoogleDocLink.normalized("mailto:me@example.com"))
        XCTAssertNil(GoogleDocLink.normalized("ftp://example.com/doc"))
    }

    func testNormalizedLinkStaysParsable() {
        let url = GoogleDocLink.normalized("docs.google.com/document/d/abc123/edit?tab=t.5")
        XCTAssertEqual(GoogleDocLink(url!)?.tab, "t.5")
    }
}
