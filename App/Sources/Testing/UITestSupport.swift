#if DEBUG
import Foundation
import PlannerCore

/// Инфраструктура для запуска UI-тестов без реального Supabase.
/// Активируется аргументом запуска `-uitest`.
enum UITestSupport {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest")
    }

    @MainActor
    static func bootstrap(env: AppEnvironment, supabase: SupabaseManager) async {
        env.testMode = true
        let remote = InMemoryRemoteStore()

        let student = Student(
            name: "Тест Ученик",
            colorHex: HexColor.palette[1],
            pricePerLesson: 1000,
            workFormat: .subscription,
            paidLessonsTotal: 4,
            lessonsUsed: 1
        )
        try? await remote.upsertStudent(student)

        // Ученица с реальным Google-документом: на ней проверяем просмотрщик.
        let ksyusha = Student(
            name: "Ксюша",
            colorHex: HexColor.palette[9],
            pricePerLesson: 1800,
            workFormat: .subscription,
            googleDocURL: SampleDocs.ksyusha,
            paidLessonsTotal: 8,
            lessonsUsed: 4
        )
        try? await remote.upsertStudent(ksyusha)

        // Уроки в заведомо известных слотах: короткий, ровно часовой и длинный.
        // На них проверяется геометрия блоков в дневной сетке.
        let seed: [(hour: Int, minutes: Int, student: Student, isPaid: Bool)] = [
            (9, 30, ksyusha, false),
            (11, 60, student, true),
            (14, 90, ksyusha, true)
        ]
        for item in seed {
            guard let start = env.calendar.date(bySettingHour: item.hour, minute: 0, second: 0, of: Date())
            else { continue }
            try? await remote.upsertLesson(
                Lesson(
                    studentId: item.student.id,
                    startAt: start,
                    durationMinutes: item.minutes,
                    isPaid: item.isPaid
                )
            )
        }

        env.connectInMemory(remote: remote)
        supabase.forceSignedIn(email: "uitest@example.com")
        await env.reloadStudents()
        await env.loadLessons(for: Date(), scope: .week)
    }
}

/// Хранилище в памяти, реализующее RemoteStore для UI-тестов.
actor InMemoryRemoteStore: RemoteStore {
    private var students: [UUID: Student] = [:]
    private var lessons: [UUID: Lesson] = [:]
    private var tasks: [UUID: PersonalTask] = [:]
    private var weekNotes: [UUID: WeekNote] = [:]

    func fetchStudents() async throws -> [Student] { Array(students.values) }
    func upsertStudent(_ student: Student) async throws { students[student.id] = student }

    /// Занятия ученика уходят вместе с ним — как каскад внешнего ключа в базе.
    func deleteStudent(id: UUID) async throws {
        students[id] = nil
        lessons = lessons.filter { $0.value.studentId != id }
    }

    func fetchLessons(in range: DateRange) async throws -> [Lesson] {
        CalendarRange.lessons(Array(lessons.values), in: range)
    }
    func upsertLesson(_ lesson: Lesson) async throws { lessons[lesson.id] = lesson }
    func upsertLessons(_ lessons: [Lesson]) async throws {
        for lesson in lessons { self.lessons[lesson.id] = lesson }
    }
    func deleteLesson(id: UUID) async throws { lessons[id] = nil }
    func deleteLessons(seriesId: UUID, after date: Date) async throws {
        lessons = lessons.filter { !($0.value.seriesId == seriesId && $0.value.startAt > date) }
    }

    func fetchTasks(in range: DateRange) async throws -> [PersonalTask] {
        CalendarRange.tasks(Array(tasks.values), in: range)
    }
    func upsertTask(_ task: PersonalTask) async throws { tasks[task.id] = task }
    func deleteTask(id: UUID) async throws { tasks[id] = nil }

    func fetchWeekNotes(weekStart: Date) async throws -> [WeekNote] {
        CalendarRange.weekNotes(Array(weekNotes.values), weekStart: weekStart)
    }
    func upsertWeekNote(_ note: WeekNote) async throws { weekNotes[note.id] = note }
    func deleteWeekNote(id: UUID) async throws { weekNotes[id] = nil }
}
#endif
