import XCTest
import Supabase
@testable import PlannerApp
import PlannerCore

/// Проверка полного круга «приложение → PostgreSQL → приложение» на настоящем
/// сервере Supabase: регистрация, запись ученика и урока, чтение их обратно.
///
/// Тест создаёт временный аккаунт, поэтому запускается только явно:
/// `RUN_NETWORK_TESTS=1 xcodebuild test …`
final class SupabaseIntegrationTests: XCTestCase {

    private var client: SupabaseClient!
    private var store: SupabaseRemoteStore!

    private static let password = "IntegrationTest123!"

    override func setUp() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_NETWORK_TESTS"] == "1",
            "Сетевой тест: запускается с RUN_NETWORK_TESTS=1"
        )

        let config = AppConfigStore.load()
        let url = try XCTUnwrap(config.normalizedURL)
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: config.normalizedKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(
                    encoder: PlannerCoding.makeEncoder(),
                    decoder: PlannerCoding.makeDecoder()
                )
            )
        )
        store = SupabaseRemoteStore(client: client)
    }

    override func tearDown() async throws {
        try? await client?.auth.signOut()
    }

    /// Завести временный аккаунт и войти под ним.
    @discardableResult
    private func signUpFreshAccount() async throws -> String {
        let address = "integration-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8))@planer-test.dev"
        _ = try await client.auth.signUp(email: address, password: Self.password)
        return address
    }

    /// Отделяет неполадки сети машины от ошибок приложения: если и этот запрос
    /// не проходит, остальные падения объясняются отсутствием связи, а не кодом.
    func testProjectHostIsReachable() async throws {
        let control = try await status(of: "https://www.apple.com")
        let project = try await status(of: SupabaseSecrets.url + "/auth/v1/health")
        XCTAssertNotNil(control, "Сети нет вообще: не открывается даже apple.com")
        XCTAssertNotNil(project, "Сеть есть, но проект Supabase недоступен")
    }

    private func status(of address: String) async throws -> Int? {
        guard let url = URL(string: address) else { return nil }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode
        } catch {
            print("UNREACHABLE \(address): \(error)")
            return nil
        }
    }

    /// Главная проверка: то, что сохранено на одном устройстве, читается на другом.
    func testStudentSurvivesRoundTripThroughServer() async throws {
        try await signUpFreshAccount()
        let student = Student(
            name: "Интеграционный ученик",
            colorHex: "#3DD598",
            pricePerLesson: 1750,
            workFormat: .subscription,
            googleDocURL: URL(string: "https://docs.google.com/document/d/test"),
            paidLessonsTotal: 8,
            lessonsUsed: 2
        )

        try await store.upsertStudent(student)
        let fetched = try await store.fetchStudents()

        let restored = try XCTUnwrap(fetched.first { $0.id == student.id })
        XCTAssertEqual(restored.name, student.name)
        XCTAssertEqual(restored.pricePerLesson, student.pricePerLesson)
        XCTAssertEqual(restored.workFormat, student.workFormat)
        XCTAssertEqual(restored.paidLessonsTotal, student.paidLessonsTotal)
        XCTAssertEqual(restored.googleDocURL, student.googleDocURL)
    }

    func testLessonSurvivesRoundTripThroughServer() async throws {
        try await signUpFreshAccount()
        let student = Student(name: "Владелец урока", pricePerLesson: 1000)
        try await store.upsertStudent(student)

        let start = Date().addingTimeInterval(3600)
        let lesson = Lesson(
            studentId: student.id,
            startAt: start,
            durationMinutes: 90,
            isPaid: true,
            note: "Проверка расписания"
        )
        try await store.upsertLesson(lesson)

        let range = DateRange(
            start: start.addingTimeInterval(-86_400),
            end: start.addingTimeInterval(86_400)
        )
        let fetched = try await store.fetchLessons(in: range)

        let restored = try XCTUnwrap(fetched.first { $0.id == lesson.id })
        XCTAssertEqual(restored.durationMinutes, 90)
        XCTAssertTrue(restored.isPaid)
        XCTAssertEqual(restored.note, "Проверка расписания")
        XCTAssertEqual(restored.startAt.timeIntervalSince1970,
                       start.timeIntervalSince1970, accuracy: 1.0)
    }

    /// Еженедельное повторение на настоящем сервере: серия уезжает одним
    /// запросом, а снятая отметка убирает только будущие повторы.
    ///
    /// Заодно проверяет, что миграция `0005_lesson_series.sql` выполнена:
    /// без колонки `series_id` сохранение занятия отвалится с ошибкой PostgREST.
    func testWeeklySeriesSurvivesRoundTripThroughServer() async throws {
        try await signUpFreshAccount()
        let student = Student(name: "Ученик серии", pricePerLesson: 1000)
        try await store.upsertStudent(student)

        let start = Date().addingTimeInterval(3600)
        let first = Lesson(studentId: student.id, startAt: start, seriesId: UUID())
        let seriesId = try XCTUnwrap(first.seriesId)
        try await store.upsertLesson(first)
        try await store.upsertLessons(
            LessonRecurrence.followingOccurrences(of: first, weeks: 3, calendar: .current)
        )

        let range = DateRange(
            start: start.addingTimeInterval(-86_400),
            end: start.addingTimeInterval(40 * 86_400)
        )
        var inSeries = try await store.fetchLessons(in: range).filter { $0.seriesId == seriesId }
        XCTAssertEqual(inSeries.count, 4, "Серия не доехала до сервера целиком")
        XCTAssertTrue(inSeries.allSatisfy(\.repeatsWeekly))

        try await store.deleteLessons(seriesId: seriesId, after: start)
        inSeries = try await store.fetchLessons(in: range).filter { $0.seriesId == seriesId }
        XCTAssertEqual(inSeries.map(\.id), [first.id],
                       "Снятая отметка обязана убрать только будущие повторы")
    }

    /// Повторное сохранение не должно плодить дубликаты и обязано доносить
    /// очистку полей до сервера.
    func testUpsertUpdatesExistingRowAndClearsFields() async throws {
        try await signUpFreshAccount()
        var student = Student(
            name: "До правки",
            pricePerLesson: 1000,
            googleDocURL: URL(string: "https://docs.google.com/document/d/before")
        )
        try await store.upsertStudent(student)

        student.name = "После правки"
        student.googleDocURL = nil
        try await store.upsertStudent(student)

        let fetched = try await store.fetchStudents()
        let matches = fetched.filter { $0.id == student.id }
        XCTAssertEqual(matches.count, 1, "Повторное сохранение создало дубликат")
        XCTAssertEqual(matches.first?.name, "После правки")
        XCTAssertNil(matches.first?.googleDocURL, "Удалённая ссылка осталась на сервере")
    }

    /// Заметка недели тоже обязана переживать круг через сервер: иначе блок
    /// «Заметки» остался бы локальным и не доехал до второго устройства.
    func testWeekNoteSurvivesRoundTripThroughServer() async throws {
        try await signUpFreshAccount()
        let weekStart = CalendarRange.week(containing: Date()).start
        let note = WeekNote(weekStart: weekStart, text: "Заказать рабочие тетради")

        try await store.upsertWeekNote(note)
        let fetched = try await store.fetchWeekNotes(weekStart: weekStart)

        let restored = try XCTUnwrap(fetched.first { $0.id == note.id })
        XCTAssertEqual(restored.text, note.text)
        XCTAssertEqual(WeekNoteDTO.dayKey(from: restored.weekStart),
                       WeekNoteDTO.dayKey(from: weekStart))

        // Правка не должна плодить дубликаты, а удаление — оставлять строку.
        var edited = restored
        edited.text = "После правки"
        try await store.upsertWeekNote(edited)
        let afterEdit = try await store.fetchWeekNotes(weekStart: weekStart)
        XCTAssertEqual(afterEdit.filter { $0.id == note.id }.map(\.text), ["После правки"])

        try await store.deleteWeekNote(id: note.id)
        let afterDelete = try await store.fetchWeekNotes(weekStart: weekStart)
        XCTAssertTrue(afterDelete.allSatisfy { $0.id != note.id })
    }

    /// Дословное воспроизведение жалобы: на одном устройстве завели учеников и
    /// расписание, на другом вошли тем же аккаунтом — всё должно быть на месте.
    ///
    /// Каждое «устройство» получает собственный пустой кэш, поэтому увиденное
    /// может прийти только с сервера.
    func testSecondDeviceSeesEverythingCreatedOnTheFirst() async throws {
        let email = try await signUpFreshAccount()
        let ownerId = try XCTUnwrap(client.auth.currentUser?.id)

        let macBook = PlannerRepository(
            remote: store,
            local: InMemoryLocalStore(),
            outbox: InMemoryOutboxStore(),
            ownerId: ownerId
        )

        let student = Student(name: "Ученик с макбука", pricePerLesson: 2000)
        let lessonStart = Date().addingTimeInterval(7200)
        let studentSent = await macBook.saveStudent(student)
        let lessonSent = await macBook.saveLesson(Lesson(studentId: student.id, startAt: lessonStart))
        XCTAssertTrue(studentSent, "Ученик не уехал на сервер")
        XCTAssertTrue(lessonSent, "Урок не уехал на сервер")

        // Второе устройство: свой клиент, свой Keychain-независимый вход, свой кэш.
        try await client.auth.signOut()
        _ = try await client.auth.signIn(email: email, password: Self.password)

        let iPhone = PlannerRepository(
            remote: store,
            local: InMemoryLocalStore(),
            outbox: InMemoryOutboxStore(),
            ownerId: ownerId
        )

        let students = await iPhone.students()
        XCTAssertEqual(students.map(\.name), ["Ученик с макбука"])

        let range = DateRange(
            start: lessonStart.addingTimeInterval(-86_400),
            end: lessonStart.addingTimeInterval(86_400)
        )
        let lessons = await iPhone.lessons(in: range)
        XCTAssertEqual(lessons.count, 1, "Расписание не доехало до второго устройства")
        XCTAssertEqual(lessons.first?.studentId, student.id)

        let reachable = await iPhone.isServerReachable()
        XCTAssertTrue(reachable)
    }

    /// Свежий аккаунт обязан видеть пустой планер: чужие записи не должны
    /// попадать в выборку.
    func testFreshAccountSeesOnlyItsOwnData() async throws {
        try await signUpFreshAccount()
        try await store.upsertStudent(Student(name: "Мой ученик", pricePerLesson: 500))

        try await signUpFreshAccount()

        let visible = try await store.fetchStudents()
        XCTAssertTrue(visible.isEmpty, "Новый аккаунт видит чужие записи: \(visible.map(\.name))")
    }
}
