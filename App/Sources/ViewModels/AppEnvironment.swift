import Foundation
import SwiftUI
import SwiftData
import PlannerCore

/// Центральное состояние приложения: репозиторий, ученики, уроки, выбранная дата.
@MainActor
final class AppEnvironment: ObservableObject {
    @Published var students: [Student] = []
    @Published var lessons: [Lesson] = []
    @Published var personalTasks: [PersonalTask] = []
    @Published var selectedDate: Date = Date()
    @Published var isSyncing = false
    @Published var isOnline = true

    // Состояние экранов живёт здесь, а не в самих `View`: на macOS разделы
    // пересоздаются при переключении вкладок, и иначе режим календаря, открытая
    // карточка ученика и выбранный месяц заработка сбрасывались бы каждый раз.
    @Published var calendarMode: CalendarViewMode = .week
    @Published var studentsPath: [Student] = []
    @Published var earningsMonth: Date = Date()
    /// В режиме UI-тестов данные хранятся в памяти, без Supabase.
    var testMode = false

    /// Календарь с началом недели в понедельник (как школьный дневник).
    var calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }()

    private let localStore: SwiftDataLocalStore
    private var repository: PlannerRepository?
    private var currentRange: DateRange?

    init(modelContainer: ModelContainer) {
        self.localStore = SwiftDataLocalStore(modelContainer: modelContainer)
    }

    /// Пересобрать репозиторий при появлении удалённого хранилища (после входа).
    func setRemoteStore(_ remote: RemoteStore?) {
        if let remote {
            repository = PlannerRepository(remote: remote, local: localStore)
        } else {
            repository = nil
        }
    }

    var hasRepository: Bool { repository != nil }

    func studentColorHex(for id: UUID) -> String {
        students.first(where: { $0.id == id })?.colorHex ?? HexColor.palette[0]
    }

    func student(for id: UUID) -> Student? {
        students.first(where: { $0.id == id })
    }

    // MARK: - Загрузка

    func reloadAll() async {
        await reloadStudents()
        if let range = currentRange {
            await loadLessons(in: range)
        }
    }

    func reloadStudents() async {
        guard let repository else { return }
        isSyncing = true
        students = await repository.students()
        isSyncing = false
    }

    func loadLessons(for referenceDate: Date, scope: CalendarScope) async {
        let range: DateRange
        switch scope {
        case .month: range = CalendarRange.month(containing: referenceDate, calendar: calendar)
        case .week: range = CalendarRange.week(containing: referenceDate, calendar: calendar)
        case .day: range = CalendarRange.day(containing: referenceDate, calendar: calendar)
        }
        await loadLessons(in: range)
    }

    private func loadLessons(in range: DateRange) async {
        guard let repository else { return }
        currentRange = range
        isSyncing = true
        lessons = await repository.lessons(in: range)
        personalTasks = await repository.tasks(in: range)
        isSyncing = false
    }

    // MARK: - Ученики

    func saveStudent(_ student: Student) async {
        guard let repository else { return }
        isOnline = await repository.saveStudent(student)
        await reloadStudents()
    }

    func deleteStudent(_ student: Student) async {
        guard let repository else { return }
        isOnline = await repository.deleteStudent(id: student.id)
        await reloadStudents()
        if let range = currentRange { await loadLessons(in: range) }
    }

    func consumePaidLesson(for student: Student) async {
        guard PaidLessons.canConsume(student) else { return }
        await saveStudent(PaidLessons.consumeOne(student))
    }

    func restorePaidLesson(for student: Student) async {
        await saveStudent(PaidLessons.restoreOne(student))
    }

    // MARK: - Уроки

    func saveLesson(_ lesson: Lesson) async {
        guard let repository else { return }
        isOnline = await repository.saveLesson(lesson)
        if let range = currentRange { await loadLessons(in: range) }
    }

    func deleteLesson(_ lesson: Lesson) async {
        guard let repository else { return }
        isOnline = await repository.deleteLesson(id: lesson.id)
        if let range = currentRange { await loadLessons(in: range) }
    }

    /// Переключить отметку «Занятие оплачено».
    ///
    /// Для учеников с форматом «Абонемент» смена отметки синхронно списывает урок
    /// из абонемента (при включении) или возвращает его (при выключении).
    /// Для «Постоплаты» меняется только сама отметка.
    func toggleLessonPaid(_ lesson: Lesson) async {
        let newPaid = !lesson.isPaid
        if let student = student(for: lesson.studentId), student.workFormat == .subscription {
            if newPaid {
                if PaidLessons.canConsume(student) {
                    await saveStudent(PaidLessons.consumeOne(student))
                }
            } else {
                await saveStudent(PaidLessons.restoreOne(student))
            }
        }
        var updated = lesson
        updated.isPaid = newPaid
        await saveLesson(updated)
    }

    func lessons(on day: Date) -> [Lesson] {
        let range = CalendarRange.day(containing: day, calendar: calendar)
        return CalendarRange.lessons(lessons, in: range).sorted { $0.startAt < $1.startAt }
    }

    // MARK: - Личные задачи (Планы)

    func tasks(on day: Date) -> [PersonalTask] {
        let range = CalendarRange.day(containing: day, calendar: calendar)
        return CalendarRange.tasks(personalTasks, in: range).sorted { $0.scheduledAt < $1.scheduledAt }
    }

    func saveTask(_ task: PersonalTask) async {
        guard let repository else { return }
        isOnline = await repository.saveTask(task)
        if let range = currentRange { await loadLessons(in: range) }
    }

    func deleteTask(_ task: PersonalTask) async {
        guard let repository else { return }
        isOnline = await repository.deleteTask(id: task.id)
        if let range = currentRange { await loadLessons(in: range) }
    }

    /// Переключить отметку «Выполнено» у личной задачи.
    func toggleTaskDone(_ task: PersonalTask) async {
        var updated = task
        updated.isDone.toggle()
        await saveTask(updated)
    }

    /// Загрузить уроки за произвольный диапазон, не меняя текущее состояние календаря
    /// (используется на экране заработка).
    func monthLessons(in range: DateRange) async -> [Lesson] {
        guard let repository else { return [] }
        return await repository.lessons(in: range)
    }
}

enum CalendarScope {
    case month, week, day
}
