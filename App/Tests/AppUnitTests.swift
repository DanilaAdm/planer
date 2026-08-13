import XCTest
import SwiftUI
import Supabase
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
            note: "Тема",
            seriesId: UUID()
        )
        let cached = CachedLesson(lesson)
        XCTAssertEqual(cached.toDomain(), lesson)
        XCTAssertTrue(cached.toDomain().repeatsWeekly)
    }

    /// Разовое занятие остаётся разовым и после кэширования.
    func testCachedSingleLessonHasNoSeries() {
        let lesson = Lesson(studentId: UUID(), startAt: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertNil(CachedLesson(lesson).toDomain().seriesId)
    }

    func testCachedWeekNoteRoundTrip() {
        let note = WeekNote(
            weekStart: Calendar.current.startOfDay(for: Date()),
            text: "Заказать тетради"
        )
        XCTAssertEqual(CachedWeekNote(note).toDomain(), note)
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

    // MARK: - Подключение по умолчанию

    /// Ключевое свойство для входа на новом устройстве: приложение готово к
    /// работе сразу после установки, без ручного ввода адреса и ключа.
    func testAppIsConfiguredOutOfTheBox() {
        AppConfigStore.resetToDefaults()
        let config = AppConfigStore.load()
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.normalizedURL?.absoluteString, SupabaseSecrets.url)
        XCTAssertEqual(config.normalizedKey, SupabaseSecrets.publishableKey)
    }

    func testEmbeddedKeyIsPublishableNotSecret() {
        XCTAssertTrue(SupabaseSecrets.publishableKey.hasPrefix("sb_publishable_"))
        XCTAssertFalse(SupabaseSecrets.publishableKey.contains("sb_secret_"),
                       "Секретный ключ обходит RLS и не должен попадать в приложение")
    }

    func testManualSettingsOverrideDefaultsAndCanBeReset() {
        let custom = AppConfig(supabaseURL: "https://custom.supabase.co", supabaseAnonKey: "custom-key")
        AppConfigStore.save(custom)
        XCTAssertEqual(AppConfigStore.load().supabaseAnonKey, "custom-key")

        AppConfigStore.resetToDefaults()
        XCTAssertEqual(AppConfigStore.load().supabaseAnonKey, SupabaseSecrets.publishableKey)
    }

    /// Пустая строка, сохранённая прежней версией приложения, не должна
    /// перекрывать зашитое значение — иначе вход снова упрётся в форму настроек.
    func testEmptySavedValueFallsBackToDefault() {
        AppConfigStore.save(AppConfig(supabaseURL: "  ", supabaseAnonKey: ""))
        let config = AppConfigStore.load()
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.normalizedKey, SupabaseSecrets.publishableKey)
        AppConfigStore.resetToDefaults()
    }

    // MARK: - Тексты ошибок входа

    func testWrongCredentialsProduceRequestedMessage() {
        let error = AuthError.api(
            message: "Invalid login credentials",
            errorCode: .invalidCredentials,
            underlyingData: Data(),
            underlyingResponse: HTTPURLResponse()
        )
        XCTAssertEqual(AuthMessage.text(for: error), "Email или пароль неверный\nПопробуйте снова")
    }

    /// «Нет такого пользователя» намеренно даёт тот же текст: иначе форма входа
    /// позволяла бы выяснять, зарегистрирован ли адрес.
    func testUnknownUserLooksTheSameAsWrongPassword() {
        let error = AuthError.api(
            message: "User not found",
            errorCode: .userNotFound,
            underlyingData: Data(),
            underlyingResponse: HTTPURLResponse()
        )
        XCTAssertEqual(AuthMessage.text(for: error), AuthMessage.invalidCredentials)
    }

    func testWeakPasswordHasItsOwnMessage() {
        let error = AuthError.api(
            message: "Password should be at least 6 characters",
            errorCode: .weakPassword,
            underlyingData: Data(),
            underlyingResponse: HTTPURLResponse()
        )
        XCTAssertTrue(AuthMessage.text(for: error).contains("6 символов"))
        XCTAssertNotEqual(AuthMessage.text(for: error), AuthMessage.invalidCredentials)
    }

    func testExistingAccountIsReportedSeparately() {
        let error = AuthError.api(
            message: "User already registered",
            errorCode: .userAlreadyExists,
            underlyingData: Data(),
            underlyingResponse: HTTPURLResponse()
        )
        XCTAssertTrue(AuthMessage.text(for: error).contains("уже существует"))
    }

    func testNoInternetIsNotReportedAsWrongPassword() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertEqual(AuthMessage.text(for: error), AuthMessage.offline)
        XCTAssertTrue(AuthMessage.isConnectivityFailure(error))
    }

    func testServerErrorIsNotTreatedAsConnectivityFailure() {
        XCTAssertFalse(AuthMessage.isConnectivityFailure(URLError(.badServerResponse)))
    }

    // MARK: - Очередь неотправленных изменений

    func testPendingChangeRoundTrip() {
        let operation = PendingOperation(
            ownerId: UUID(),
            kind: .upsertLesson,
            entityId: UUID(),
            payload: Data("{}".utf8)
        )
        let restored = PendingChange(operation).toDomain()
        XCTAssertEqual(restored, operation)
    }

    /// Запись, оставленную более новой версией приложения, надо пропускать, а не
    /// падать на ней.
    func testUnknownPendingKindIsIgnored() {
        let change = PendingChange(
            PendingOperation(ownerId: UUID(), kind: .upsertTask, entityId: UUID(), payload: nil)
        )
        change.kindRaw = "somethingFromTheFuture"
        XCTAssertNil(change.toDomain())
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

    // MARK: - Проверка обновлений

    private static let releaseStub = ReleaseInfo(
        version: AppVersion("1.1.0")!,
        pageURL: URL(string: "https://github.com/DanilaAdm/planer/releases/tag/v1.1.0")!,
        downloadURL: URL(string: "https://github.com/DanilaAdm/planer/releases/download/v1.1.0/PlannerApp-macOS.dmg")!
    )

    /// Отдельное хранилище настроек: тест не должен запоминать «баннер закрыт»
    /// в настройках самого приложения.
    private func makeDefaults() throws -> UserDefaults {
        let name = "UpdateCheckerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    @MainActor
    func testNewerReleaseShowsBanner() async throws {
        let checker = UpdateChecker(
            installedVersion: "1.0.0",
            defaults: try makeDefaults(),
            fetchLatest: { Self.releaseStub }
        )
        await checker.check()

        XCTAssertEqual(checker.status, .available(Self.releaseStub))
        XCTAssertEqual(checker.bannerRelease, Self.releaseStub)
    }

    @MainActor
    func testSameOrNewerInstalledVersionShowsNoBanner() async throws {
        for installed in ["1.1.0", "1.2.0"] {
            let checker = UpdateChecker(
                installedVersion: installed,
                defaults: try makeDefaults(),
                fetchLatest: { Self.releaseStub }
            )
            await checker.check()

            XCTAssertEqual(checker.status, .upToDate, "Версия \(installed)")
            XCTAssertNil(checker.bannerRelease)
        }
    }

    /// Закрытый баннер не возвращается для той же версии, но в настройках
    /// обновление по-прежнему видно.
    @MainActor
    func testDismissedBannerStaysHiddenForSameVersion() async throws {
        let defaults = try makeDefaults()
        let checker = UpdateChecker(
            installedVersion: "1.0.0",
            defaults: defaults,
            fetchLatest: { Self.releaseStub }
        )
        await checker.check()
        checker.dismissBanner()

        XCTAssertNil(checker.bannerRelease)
        XCTAssertEqual(checker.status, .available(Self.releaseStub))

        // Новый запуск приложения: решение пользователя пережило перезапуск.
        let restarted = UpdateChecker(
            installedVersion: "1.0.0",
            defaults: defaults,
            fetchLatest: { Self.releaseStub }
        )
        await restarted.check()
        XCTAssertNil(restarted.bannerRelease)
    }

    /// Следующий релиз должен пробиться сквозь ранее закрытый баннер.
    @MainActor
    func testDismissedBannerReappearsForNextVersion() async throws {
        let defaults = try makeDefaults()
        let older = UpdateChecker(
            installedVersion: "1.0.0",
            defaults: defaults,
            fetchLatest: { Self.releaseStub }
        )
        await older.check()
        older.dismissBanner()

        let next = ReleaseInfo(
            version: AppVersion("1.2.0")!,
            pageURL: Self.releaseStub.pageURL,
            downloadURL: nil
        )
        let checker = UpdateChecker(
            installedVersion: "1.0.0",
            defaults: defaults,
            fetchLatest: { next }
        )
        await checker.check()

        XCTAssertEqual(checker.bannerRelease, next)
    }

    /// Нет сети — нет баннера и никаких сообщений об ошибке поверх приложения.
    @MainActor
    func testFailedCheckIsSilent() async throws {
        let checker = UpdateChecker(
            installedVersion: "1.0.0",
            defaults: try makeDefaults(),
            fetchLatest: { throw URLError(.notConnectedToInternet) }
        )
        await checker.check()

        XCTAssertEqual(checker.status, .failed)
        XCTAssertNil(checker.bannerRelease)
    }

    /// Автоматическая проверка не ходит в сеть на каждый возврат в приложение,
    /// а кнопка в настройках срабатывает всегда.
    @MainActor
    func testAutomaticChecksAreThrottledButForcedOneIsNot() async throws {
        let counter = CallCounter()
        let checker = UpdateChecker(
            installedVersion: "1.0.0",
            defaults: try makeDefaults(),
            minimumInterval: 600,
            fetchLatest: {
                await counter.increment()
                return Self.releaseStub
            }
        )

        await checker.check()
        await checker.check()
        var count = await counter.count
        XCTAssertEqual(count, 1)

        await checker.check(force: true)
        count = await counter.count
        XCTAssertEqual(count, 2)
    }

    /// Неудачная проверка не занимает интервал: следующая попытка идёт в сеть.
    @MainActor
    func testFailedCheckIsRetriedWithoutWaiting() async throws {
        let counter = CallCounter()
        let checker = UpdateChecker(
            installedVersion: "1.0.0",
            defaults: try makeDefaults(),
            minimumInterval: 600,
            fetchLatest: {
                await counter.increment()
                throw URLError(.timedOut)
            }
        )

        await checker.check()
        await checker.check()
        let count = await counter.count
        XCTAssertEqual(count, 2)
    }

    /// Реальный ответ GitHub: сетевой тест, включается через RUN_NETWORK_TESTS=1.
    func testLatestReleaseIsReadableFromGitHub() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_NETWORK_TESTS"] == "1",
            "Сетевой тест: запускается с RUN_NETWORK_TESTS=1"
        )

        let release: ReleaseInfo
        do {
            release = try await GitHubReleases.latest()
        } catch let error as URLError where Self.connectivityErrors.contains(error.code) {
            throw XCTSkip("Нет доступа к сети: \(error.localizedDescription)")
        }

        XCTAssertGreaterThanOrEqual(release.version, AppVersion("1.0.0")!)
        XCTAssertNotNil(release.downloadURL, "В релизе нет файла PlannerApp-macOS.dmg")
    }
}

/// Счётчик обращений к сети для тестов проверки обновлений.
private actor CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}
