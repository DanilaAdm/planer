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
    /// Сколько изменений ещё не уехало на сервер.
    @Published private(set) var pendingChangesCount = 0

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

    /// Кому принадлежит содержимое локального кэша.
    private static let cacheOwnerKey = "cached_owner_id"

    init(modelContainer: ModelContainer) {
        self.localStore = SwiftDataLocalStore(modelContainer: modelContainer)
    }

    /// Подключить хранилище реального пользователя после входа.
    ///
    /// Перед этим кэш проверяется на принадлежность: если на устройстве лежат
    /// данные другого аккаунта, они стираются. Иначе при первой же неудачной
    /// загрузке репозиторий отдал бы их как данные текущего пользователя.
    func connect(remote: RemoteStore, ownerId: UUID) async {
        await discardCacheIfForeign(ownerId: ownerId)
        repository = PlannerRepository(
            remote: remote,
            local: localStore,
            outbox: localStore,
            ownerId: ownerId
        )
        await syncPending()
    }

    /// Подключить хранилища демо-режима и UI-тестов: и удалённое, и локальное
    /// живут в памяти, поэтому база устройства не затрагивается.
    func connectInMemory(remote: RemoteStore) {
        repository = PlannerRepository(remote: remote, local: InMemoryLocalStore())
        pendingChangesCount = 0
    }

    func disconnect() {
        repository = nil
        pendingChangesCount = 0
        isOnline = true
        // Показанные данные принадлежали вышедшему пользователю: держать их в
        // памяти незачем, иначе они мелькнут при следующем входе.
        students = []
        lessons = []
        personalTasks = []
    }

    var hasRepository: Bool { repository != nil }

    private func discardCacheIfForeign(ownerId: UUID) async {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: Self.cacheOwnerKey)
        guard previous != ownerId.uuidString else { return }
        try? await localStore.clearAll()
        students = []
        lessons = []
        personalTasks = []
        defaults.set(ownerId.uuidString, forKey: Self.cacheOwnerKey)
    }

    /// Досылка изменений, накопленных без интернета.
    func syncPending() async {
        guard let repository else { return }
        await repository.flushPending()
        await refreshSyncState()
    }

    /// Отправить на сервер всё, что лежит на этом устройстве.
    ///
    /// Ручное восстановление для случая «на компьютере данные есть, на телефоне
    /// пусто»: доносит записи, которые не доехали и не попали в очередь.
    func uploadLocalData() async {
        guard let repository else { return }
        isSyncing = true
        await repository.uploadLocalCache()
        isSyncing = false
        await reloadAll()
    }

    /// Забрать у репозитория итог последнего обмена с сервером.
    private func refreshSyncState() async {
        guard let repository else { return }
        pendingChangesCount = await repository.pendingCount()
        isOnline = await repository.isServerReachable()
    }

    func studentColorHex(for id: UUID) -> String {
        students.first(where: { $0.id == id })?.colorHex ?? HexColor.palette[0]
    }

    func student(for id: UUID) -> Student? {
        students.first(where: { $0.id == id })
    }

    // MARK: - Загрузка

    func reloadAll() async {
        // Ручное обновление — самый подходящий момент дожать очередь: обычно
        // его нажимают именно после того, как связь вернулась.
        await syncPending()
        await reloadStudents()
        if let range = currentRange {
            await loadLessons(in: range)
        }
    }

    func reloadStudents() async {
        guard let repository else { return }
        isSyncing = true
        students = await repository.students()
        await refreshSyncState()
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
        await refreshSyncState()
        isSyncing = false
    }

    // MARK: - Ученики

    func saveStudent(_ student: Student) async {
        guard let repository else { return }
        await repository.saveStudent(student)
        await reloadStudents()
    }

    func deleteStudent(_ student: Student) async {
        guard let repository else { return }
        await repository.deleteStudent(id: student.id)
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
        await repository.saveLesson(lesson)
        if let range = currentRange { await loadLessons(in: range) } else { await refreshSyncState() }
    }

    func deleteLesson(_ lesson: Lesson) async {
        guard let repository else { return }
        await repository.deleteLesson(id: lesson.id)
        if let range = currentRange { await loadLessons(in: range) } else { await refreshSyncState() }
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
        await repository.saveTask(task)
        if let range = currentRange { await loadLessons(in: range) } else { await refreshSyncState() }
    }

    func deleteTask(_ task: PersonalTask) async {
        guard let repository else { return }
        await repository.deleteTask(id: task.id)
        if let range = currentRange { await loadLessons(in: range) } else { await refreshSyncState() }
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
