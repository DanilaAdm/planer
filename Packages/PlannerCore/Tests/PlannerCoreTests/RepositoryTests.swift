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
}
