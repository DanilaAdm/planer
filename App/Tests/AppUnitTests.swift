import XCTest
import SwiftUI
@testable import PlannerApp
import PlannerCore

final class AppUnitTests: XCTestCase {

    func testAppConfigIsConfigured() {
        XCTAssertFalse(AppConfig.empty.isConfigured)
        XCTAssertTrue(AppConfig(supabaseURL: "https://x.supabase.co", supabaseAnonKey: "key").isConfigured)
        XCTAssertFalse(AppConfig(supabaseURL: "not-a-url", supabaseAnonKey: "key").isConfigured)
        XCTAssertFalse(AppConfig(supabaseURL: "https://x.supabase.co", supabaseAnonKey: "  ").isConfigured)
    }

    func testCachedStudentRoundTrip() {
        let student = Student(
            name: "Тест",
            colorHex: "#FF6B6B",
            pricePerLesson: 1200,
            workFormat: .subscription,
            googleDocURL: URL(string: "https://docs.google.com/x"),
            paidLessonsTotal: 4,
            lessonsUsed: 2
        )
        let cached = CachedStudent(student)
        let restored = cached.toDomain()
        XCTAssertEqual(restored, student)
    }

    func testCachedLessonRoundTrip() {
        let lesson = Lesson(
            studentId: UUID(),
            startAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 90,
            isPaid: true,
            note: "Тема"
        )
        let cached = CachedLesson(lesson)
        XCTAssertEqual(cached.toDomain(), lesson)
    }

    func testReadableTextContrast() {
        XCTAssertEqual(Color.readableText(on: "#FFFFFF"), .black)
        XCTAssertEqual(Color.readableText(on: "#000000"), .white)
    }

    func testMoneyFormatterNonEmpty() {
        XCTAssertFalse(Formatters.money(1000).isEmpty)
    }

    func testNormalizedURLStripsRestPath() {
        let config = AppConfig(
            supabaseURL: "https://abc.supabase.co/rest/v1/",
            supabaseAnonKey: "key"
        )
        XCTAssertEqual(config.normalizedURL?.absoluteString, "https://abc.supabase.co")
    }

    func testNormalizedURLAddsSchemeAndTrimsSpaces() {
        let config = AppConfig(supabaseURL: "  abc.supabase.co  ", supabaseAnonKey: "key")
        XCTAssertEqual(config.normalizedURL?.absoluteString, "https://abc.supabase.co")
    }

    func testNormalizedURLRejectsHostWithoutDot() {
        let config = AppConfig(supabaseURL: "https://localhost", supabaseAnonKey: "key")
        XCTAssertNil(config.normalizedURL)
    }

    func testIsConfiguredRequiresKey() {
        XCTAssertFalse(AppConfig(supabaseURL: "https://abc.supabase.co", supabaseAnonKey: "  ").isConfigured)
        XCTAssertTrue(AppConfig(supabaseURL: "https://abc.supabase.co/rest/v1/", supabaseAnonKey: "k").isConfigured)
    }

    // MARK: - Google-документ ученика

    private static let connectivityErrors: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
        .cannotConnectToHost, .dnsLookupFailed, .timedOut
    ]

    func testSampleDocPointsToKsyushaDocument() {
        let link = GoogleDocLink(SampleDocs.ksyusha)
        XCTAssertEqual(link?.documentId, "1GJCIgRcxw_RF4ku98-7-uQwNv4I6Y_Gn8SSJQ9aYCN0")
        XCTAssertEqual(link?.kind, .document)
        XCTAssertEqual(
            link?.readerURL.absoluteString,
            "https://docs.google.com/document/d/1GJCIgRcxw_RF4ku98-7-uQwNv4I6Y_Gn8SSJQ9aYCN0/mobilebasic?tab=t.0"
        )
    }

    func testDocReaderStyleHidesGoogleInterfaceAndSupportsDarkMode() {
        let css = DocReaderStyle.css
        XCTAssertTrue(css.contains(".docs-ml-header"))
        XCTAssertTrue(css.contains(".docs-ml-promotion"))
        XCTAssertFalse(css.contains("[class^=\"docs-ml-\"]"))
        XCTAssertTrue(css.contains("display: none !important"))
        XCTAssertTrue(css.contains(".doc-content"))
        XCTAssertTrue(css.contains("prefers-color-scheme: dark"))
        XCTAssertTrue(css.contains("max-width: 100% !important"))
    }

    func testDocReaderErrorMessages() {
        XCTAssertTrue(DocReaderModel.message(forStatusCode: 403).contains("доступ"))
        XCTAssertTrue(DocReaderModel.message(forStatusCode: 404).contains("не найден"))
        XCTAssertTrue(DocReaderModel.message(forStatusCode: 500).contains("500"))
    }

    /// Проверяет, что документ Ксюши действительно открыт по ссылке и читается
    /// без входа в Google. Сетевой тест, поэтому включается явно:
    /// `TEST_RUNNER_RUN_NETWORK_TESTS=1 xcodebuild test …`
    func testKsyushaDocumentIsReadableWithoutSignIn() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_NETWORK_TESTS"] == "1",
            "Сетевой тест: запускается с RUN_NETWORK_TESTS=1"
        )

        let url = try XCTUnwrap(GoogleDocLink(SampleDocs.ksyusha)?.readerURL)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch let error as URLError where Self.connectivityErrors.contains(error.code) {
            // Машина без доступа к сети (VPN, офлайн) — проверять доступ к документу нечем.
            throw XCTSkip("Нет доступа к сети: \(error.localizedDescription)")
        }

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let html = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(html.contains("Ксюша"), "В документе нет заголовка с именем ученицы")
        XCTAssertTrue(html.contains("РУССКИЙ ЯЗЫК"), "В документе нет раздела по русскому языку")
        XCTAssertFalse(html.contains("accounts.google.com/ServiceLogin"),
                       "Google требует вход — документ закрыт настройками доступа")
    }
}
