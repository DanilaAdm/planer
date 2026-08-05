import XCTest
@testable import PlannerCore

/// Мок-хранилище в памяти для проверки логики репозитория.
private actor MockRemote: RemoteStore {
    var students: [UUID: Student] = [:]
    var lessons: [UUID: Lesson] = [:]
    var tasks: [UUID: PersonalTask] = [:]
    var shouldFail = false

    func setShouldFail(_ value: Bool) { shouldFail = value }
    func seedStudent(_ s: Student) { students[s.id] = s }
    func seedLesson(_ l: Lesson) { lessons[l.id] = l }

    struct Offline: Error {}

    func fetchStudents() async throws -> [Student] {
        if shouldFail { throw Offline() }
        return Array(students.values)
    }
    func upsertStudent(_ student: Student) async throws {
        if shouldFail { throw Offline() }
        students[student.id] = student
    }
    func deleteStudent(id: UUID) async throws {
        if shouldFail { throw Offline() }
        students[id] = nil
    }
    func fetchLessons(in range: DateRange) async throws -> [Lesson] {
        if shouldFail { throw Offline() }
        return CalendarRange.lessons(Array(lessons.values), in: range)
    }
    func upsertLesson(_ lesson: Lesson) async throws {
        if shouldFail { throw Offline() }
        lessons[lesson.id] = lesson
    }
    func deleteLesson(id: UUID) async throws {
        if shouldFail { throw Offline() }
        lessons[id] = nil
    }
    func fetchTasks(in range: DateRange) async throws -> [PersonalTask] {
        if shouldFail { throw Offline() }
        return CalendarRange.tasks(Array(tasks.values), in: range)
    }
    func upsertTask(_ task: PersonalTask) async throws {
        if shouldFail { throw Offline() }
        tasks[task.id] = task
    }
    func deleteTask(id: UUID) async throws {
        if shouldFail { throw Offline() }
        tasks[id] = nil
    }
}

private actor MockLocal: LocalStore {
    var students: [UUID: Student] = [:]
    var lessons: [UUID: Lesson] = [:]
    var tasks: [UUID: PersonalTask] = [:]

    func clearAll() async throws {
        students.removeAll()
        lessons.removeAll()
        tasks.removeAll()
    }

    func loadStudents() async throws -> [Student] { Array(students.values) }
    func saveStudents(_ students: [Student]) async throws {
        self.students = Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
    }
    func upsertStudent(_ student: Student) async throws { students[student.id] = student }
    func deleteStudent(id: UUID) async throws { students[id] = nil }

    func loadLessons() async throws -> [Lesson] { Array(lessons.values) }
    func saveLessons(_ lessons: [Lesson]) async throws {
        self.lessons = Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0) })
    }
    func upsertLesson(_ lesson: Lesson) async throws { lessons[lesson.id] = lesson }
    func deleteLesson(id: UUID) async throws { lessons[id] = nil }

    func loadTasks() async throws -> [PersonalTask] { Array(tasks.values) }
    func saveTasks(_ tasks: [PersonalTask]) async throws {
        self.tasks = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
    }
    func upsertTask(_ task: PersonalTask) async throws { tasks[task.id] = task }
    func deleteTask(id: UUID) async throws { tasks[id] = nil }
}

final class RepositoryTests: XCTestCase {
    func testStudentsFromRemoteUpdatesCache() async {
        let remote = MockRemote()
        let local = MockLocal()
        let student = TestSupport.makeStudent(name: "Аня")
        await remote.seedStudent(student)

        let repo = PlannerRepository(remote: remote, local: local)
        let result = await repo.students()

        XCTAssertEqual(result.count, 1)
        let cached = try? await local.loadStudents()
        XCTAssertEqual(cached?.count, 1)
    }

    func testStudentsFallBackToCacheWhenOffline() async {
        let remote = MockRemote()
        let local = MockLocal()
        try? await local.saveStudents([TestSupport.makeStudent(name: "Кэш")])
        await remote.setShouldFail(true)

        let repo = PlannerRepository(remote: remote, local: local)
        let result = await repo.students()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Кэш")
    }

    func testStudentsSortedByName() async {
        let remote = MockRemote()
        await remote.seedStudent(TestSupport.makeStudent(name: "Яна"))
        await remote.seedStudent(TestSupport.makeStudent(name: "Артём"))
        let repo = PlannerRepository(remote: remote, local: MockLocal())
        let result = await repo.students()
        XCTAssertEqual(result.map(\.name), ["Артём", "Яна"])
    }

    func testSaveStudentReturnsFalseWhenOfflineButUpdatesCache() async {
        let remote = MockRemote()
        let local = MockLocal()
        await remote.setShouldFail(true)
        let repo = PlannerRepository(remote: remote, local: local)

        let student = TestSupport.makeStudent(name: "Офлайн")
        let synced = await repo.saveStudent(student)

        XCTAssertFalse(synced)
        let cached = try? await local.loadStudents()
        XCTAssertEqual(cached?.first?.name, "Офлайн")
    }

    func testSaveStudentReturnsTrueWhenOnline() async {
        let remote = MockRemote()
        let repo = PlannerRepository(remote: remote, local: MockLocal())
        let synced = await repo.saveStudent(TestSupport.makeStudent(name: "Онлайн"))
        XCTAssertTrue(synced)
    }

    func testLessonsInRangeSorted() async {
        let remote = MockRemote()
        let sid = UUID()
        await remote.seedLesson(Lesson(studentId: sid, startAt: TestSupport.date(2026, 3, 2, 15)))
        await remote.seedLesson(Lesson(studentId: sid, startAt: TestSupport.date(2026, 3, 2, 9)))
        let repo = PlannerRepository(remote: remote, local: MockLocal())

        let range = CalendarRange.day(containing: TestSupport.date(2026, 3, 2), calendar: TestSupport.utcCalendar)
        let result = await repo.lessons(in: range)

        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result[0].startAt < result[1].startAt)
    }

    func testDeleteLessonUpdatesCache() async {
        let remote = MockRemote()
        let local = MockLocal()
        let lesson = Lesson(studentId: UUID(), startAt: TestSupport.date(2026, 3, 2, 10))
        await remote.seedLesson(lesson)
        try? await local.saveLessons([lesson])

        let repo = PlannerRepository(remote: remote, local: local)
        let ok = await repo.deleteLesson(id: lesson.id)

        XCTAssertTrue(ok)
        let cached = try? await local.loadLessons()
        XCTAssertEqual(cached?.count, 0)
    }

    // MARK: - Доступность сервера

    /// Главная защита от «данные пропали»: пустой результат при недоступном
    /// сервере обязан быть отличим от честного «у пользователя ничего нет».
    func testUnreachableServerIsReportedInsteadOfLookingEmpty() async {
        let remote = MockRemote()
        await remote.setShouldFail(true)
        let repo = PlannerRepository(remote: remote, local: MockLocal())

        let result = await repo.students()

        XCTAssertTrue(result.isEmpty)
        let reachable = await repo.isServerReachable()
        XCTAssertFalse(reachable, "Пустой список без связи нельзя выдавать за отсутствие данных")
    }

    func testSuccessfulReadMarksServerReachableAgain() async {
        let remote = MockRemote()
        let repo = PlannerRepository(remote: remote, local: MockLocal())

        await remote.setShouldFail(true)
        _ = await repo.students()
        await remote.setShouldFail(false)
        _ = await repo.students()

        let reachable = await repo.isServerReachable()
        XCTAssertTrue(reachable)
    }

    func testFailedLessonLoadMarksServerUnreachable() async {
        let remote = MockRemote()
        await remote.setShouldFail(true)
        let repo = PlannerRepository(remote: remote, local: MockLocal())

        let range = CalendarRange.day(containing: TestSupport.date(2026, 3, 2), calendar: TestSupport.utcCalendar)
        _ = await repo.lessons(in: range)

        let reachable = await repo.isServerReachable()
        XCTAssertFalse(reachable)
    }

    /// Пустая очередь означает лишь то, что отправлять нечего: выдавать это за
    /// подтверждённую связь нельзя, иначе приложение снова покажет «Онлайн»
    /// поверх пустого экрана.
    func testEmptyFlushDoesNotClaimServerIsReachable() async {
        let remote = MockRemote()
        await remote.setShouldFail(true)
        let repo = makeRepository(remote: remote, outbox: InMemoryOutboxStore(), owner: UUID())

        _ = await repo.students()
        let flushed = await repo.flushPending()

        XCTAssertTrue(flushed, "Очередь пуста — отправлять нечего")
        let reachable = await repo.isServerReachable()
        XCTAssertFalse(reachable, "Связь не проверялась, прежний вывод менять нельзя")
    }

    // MARK: - Очередь досылки

    private func makeRepository(
        remote: MockRemote,
        local: MockLocal = MockLocal(),
        outbox: InMemoryOutboxStore,
        owner: UUID
    ) -> PlannerRepository {
        PlannerRepository(remote: remote, local: local, outbox: outbox, ownerId: owner)
    }

    func testOfflineSaveIsQueuedAndSentWhenBackOnline() async {
        let remote = MockRemote()
        let outbox = InMemoryOutboxStore()
        let owner = UUID()
        let repo = makeRepository(remote: remote, outbox: outbox, owner: owner)
        await remote.setShouldFail(true)

        let student = TestSupport.makeStudent(name: "Офлайн")
        let synced = await repo.saveStudent(student)
        XCTAssertFalse(synced)

        var queued = await repo.pendingCount()
        XCTAssertEqual(queued, 1, "Правка без сети должна попасть в очередь, а не потеряться")

        await remote.setShouldFail(false)
        let flushed = await repo.flushPending()

        XCTAssertTrue(flushed)
        queued = await repo.pendingCount()
        XCTAssertEqual(queued, 0)
        let onServer = try? await remote.fetchStudents()
        XCTAssertEqual(onServer?.first?.name, "Офлайн")
    }

    func testQueueKeepsOnlyLatestStateOfSameEntity() async {
        let remote = MockRemote()
        let outbox = InMemoryOutboxStore()
        let repo = makeRepository(remote: remote, outbox: outbox, owner: UUID())
        await remote.setShouldFail(true)

        var student = TestSupport.makeStudent(name: "Первая версия")
        await repo.saveStudent(student)
        student.name = "Вторая версия"
        await repo.saveStudent(student)

        let queued = await repo.pendingCount()
        XCTAssertEqual(queued, 1, "История правок не нужна — на сервер уезжает итоговое состояние")

        await remote.setShouldFail(false)
        await repo.flushPending()

        let onServer = try? await remote.fetchStudents()
        XCTAssertEqual(onServer?.first?.name, "Вторая версия")
    }

    func testFlushStopsWhenConnectionIsStillDown() async {
        let remote = MockRemote()
        let outbox = InMemoryOutboxStore()
        let repo = makeRepository(remote: remote, outbox: outbox, owner: UUID())
        await remote.setShouldFail(true)

        await repo.saveStudent(TestSupport.makeStudent(name: "Ждёт"))
        let flushed = await repo.flushPending()

        XCTAssertFalse(flushed)
        let queued = await repo.pendingCount()
        XCTAssertEqual(queued, 1, "Неотправленная правка обязана остаться в очереди")
    }

    func testStudentsAreSentBeforeLessonsThatReferenceThem() async {
        let remote = MockRemote()
        let outbox = InMemoryOutboxStore()
        let owner = UUID()
        let repo = makeRepository(remote: remote, outbox: outbox, owner: owner)
        await remote.setShouldFail(true)

        // Урок добавлен раньше ученика: при отправке порядок обязан
        // перевернуться, иначе внешний ключ на сервере не сойдётся.
        let student = TestSupport.makeStudent(name: "Новый")
        await repo.saveLesson(Lesson(studentId: student.id, startAt: TestSupport.date(2026, 3, 2, 10)))
        await repo.saveStudent(student)

        let queued = try? await outbox.pending(ownerId: owner)
        XCTAssertEqual(queued?.first?.kind, .upsertStudent)
        XCTAssertEqual(queued?.last?.kind, .upsertLesson)
    }

    func testQueueIsScopedToOwner() async {
        let outbox = InMemoryOutboxStore()
        let first = UUID()
        let second = UUID()
        let repoA = makeRepository(remote: MockRemote(), outbox: outbox, owner: first)
        await repoA.saveStudent(TestSupport.makeStudent(name: "Чужой"))

        let remoteB = MockRemote()
        await remoteB.setShouldFail(true)
        let repoB = makeRepository(remote: remoteB, outbox: outbox, owner: second)
        await repoB.saveStudent(TestSupport.makeStudent(name: "Свой"))

        let countB = await repoB.pendingCount()
        XCTAssertEqual(countB, 1, "В очереди пользователя не должно быть чужих операций")
    }

    /// Восстановление данных, которые остались только на устройстве: без него
    /// пользователю пришлось бы заводить учеников и расписание заново.
    func testUploadLocalCachePushesEverythingThatNeverReachedServer() async {
        let remote = MockRemote()
        let local = MockLocal()
        let student = TestSupport.makeStudent(name: "Только на устройстве")
        let lesson = Lesson(studentId: student.id, startAt: TestSupport.date(2026, 3, 2, 10))
        try? await local.saveStudents([student])
        try? await local.saveLessons([lesson])

        let repo = makeRepository(remote: remote, local: local, outbox: InMemoryOutboxStore(), owner: UUID())
        let uploaded = await repo.uploadLocalCache()

        XCTAssertTrue(uploaded)
        let onServer = try? await remote.fetchStudents()
        XCTAssertEqual(onServer?.first?.name, "Только на устройстве")
        let range = CalendarRange.day(containing: TestSupport.date(2026, 3, 2), calendar: TestSupport.utcCalendar)
        let lessonsOnServer = try? await remote.fetchLessons(in: range)
        XCTAssertEqual(lessonsOnServer?.count, 1)
    }

    func testUploadLocalCacheKeepsDataQueuedWhileOffline() async {
        let remote = MockRemote()
        let local = MockLocal()
        try? await local.saveStudents([TestSupport.makeStudent(name: "Ждёт связи")])
        await remote.setShouldFail(true)

        let repo = makeRepository(remote: remote, local: local, outbox: InMemoryOutboxStore(), owner: UUID())
        let uploaded = await repo.uploadLocalCache()

        XCTAssertFalse(uploaded)
        let queued = await repo.pendingCount()
        XCTAssertEqual(queued, 1, "Без связи данные обязаны остаться в очереди, а не пропасть")
    }

    func testOfflineDeleteReachesServerAfterFlush() async {
        let remote = MockRemote()
        let outbox = InMemoryOutboxStore()
        let lesson = Lesson(studentId: UUID(), startAt: TestSupport.date(2026, 3, 2, 10))
        await remote.seedLesson(lesson)
        let repo = makeRepository(remote: remote, outbox: outbox, owner: UUID())

        await remote.setShouldFail(true)
        await repo.deleteLesson(id: lesson.id)
        await remote.setShouldFail(false)
        await repo.flushPending()

        let range = CalendarRange.day(containing: TestSupport.date(2026, 3, 2), calendar: TestSupport.utcCalendar)
        let remaining = try? await remote.fetchLessons(in: range)
        XCTAssertEqual(remaining?.count, 0)
    }
}
