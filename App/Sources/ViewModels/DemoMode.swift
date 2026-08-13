import Foundation
import PlannerCore

/// Демо-режим: позволяет войти в приложение без Supabase и посмотреть интерфейс
/// на заранее подготовленных данных (ученики, уроки, личные задачи «Планы»).
enum DemoMode {
    @MainActor
    static func enter(env: AppEnvironment, supabase: SupabaseManager) async {
        // Не даём RootView перезаписать демо-хранилище реальным Supabase-клиентом.
        env.testMode = true

        let cal = env.calendar
        let weekStart = CalendarRange.week(containing: Date(), calendar: cal).start

        func date(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let anna = Student(name: "Анна", colorHex: HexColor.palette[0],
                           pricePerLesson: 1500, workFormat: .subscription,
                           paidLessonsTotal: 8, lessonsUsed: 3)
        let maxim = Student(name: "Максим", colorHex: HexColor.palette[1],
                            pricePerLesson: 1200, workFormat: .postpay)
        // У Софии остался последний оплаченный урок — на ней видна подсветка.
        let sofia = Student(name: "София", colorHex: HexColor.palette[2],
                            pricePerLesson: 2000, workFormat: .subscription,
                            paidLessonsTotal: 4, lessonsUsed: 3)
        let egor = Student(name: "Егор", colorHex: HexColor.palette[3],
                           pricePerLesson: 1000, workFormat: .postpay)
        // У Ксюши есть реальный Google-документ с пройденными темами.
        let ksyusha = Student(name: "Ксюша", colorHex: HexColor.palette[9],
                              pricePerLesson: 1800, workFormat: .subscription,
                              googleDocURL: SampleDocs.ksyusha,
                              paidLessonsTotal: 8, lessonsUsed: 4)
        let students = [anna, maxim, sofia, egor, ksyusha]

        let lessons: [Lesson] = [
            Lesson(studentId: anna.id, startAt: date(dayOffset: 0, hour: 10), durationMinutes: 60,
                   isPaid: true, note: "Уравнения с параметром"),
            Lesson(studentId: maxim.id, startAt: date(dayOffset: 0, hour: 16), durationMinutes: 90,
                   note: "Сочинение, разбор ошибок"),
            Lesson(studentId: sofia.id, startAt: date(dayOffset: 1, hour: 12), durationMinutes: 60,
                   isPaid: true, note: "Present Perfect"),
            Lesson(studentId: egor.id, startAt: date(dayOffset: 1, hour: 15), durationMinutes: 45,
                   note: "Дроби"),
            Lesson(studentId: anna.id, startAt: date(dayOffset: 2, hour: 15), durationMinutes: 60,
                   note: "Производные"),
            Lesson(studentId: maxim.id, startAt: date(dayOffset: 3, hour: 11), durationMinutes: 90,
                   isPaid: true, note: "Пробное ЕГЭ"),
            Lesson(studentId: sofia.id, startAt: date(dayOffset: 4, hour: 14), durationMinutes: 60,
                   note: "Разговорная практика"),
            Lesson(studentId: ksyusha.id, startAt: date(dayOffset: 2, hour: 10), durationMinutes: 60,
                   isPaid: true, note: "Математика: письменное деление"),
            Lesson(studentId: ksyusha.id, startAt: date(dayOffset: 4, hour: 12), durationMinutes: 60,
                   note: "Английский: предлоги места")
        ]

        let tasks: [PersonalTask] = [
            PersonalTask(title: "Проверить тетради", scheduledAt: date(dayOffset: 0, hour: 9),
                         note: "Анна и Максим"),
            PersonalTask(title: "Купить маркеры", scheduledAt: date(dayOffset: 2, hour: 18),
                         isDone: true),
            PersonalTask(title: "Составить план на неделю", scheduledAt: date(dayOffset: 4, hour: 17),
                         note: "Темы и материалы")
        ]

        let notes: [WeekNote] = [
            WeekNote(weekStart: weekStart, text: "Заказать рабочие тетради на сентябрь"),
            WeekNote(weekStart: weekStart, text: "Позвонить маме Егора по расписанию")
        ]

        let remote = DemoRemoteStore()
        await remote.seed(students: students, lessons: lessons, tasks: tasks, notes: notes)
        // Кэш демо-режима тоже в памяти: демонстрационные ученики не должны
        // оседать в базе устройства и всплывать потом у реального пользователя.
        env.connectInMemory(remote: remote)

        supabase.signInDemo()
        await env.reloadStudents()
        await env.loadLessons(for: env.selectedDate, scope: .week)
    }
}

/// Хранилище в памяти для демо-режима (реализует RemoteStore без обращения к сети).
actor DemoRemoteStore: RemoteStore {
    private var students: [UUID: Student] = [:]
    private var lessons: [UUID: Lesson] = [:]
    private var tasks: [UUID: PersonalTask] = [:]
    private var weekNotes: [UUID: WeekNote] = [:]

    func seed(students: [Student], lessons: [Lesson], tasks: [PersonalTask], notes: [WeekNote]) {
        self.students = Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
        self.lessons = Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0) })
        self.tasks = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        self.weekNotes = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
    }

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
