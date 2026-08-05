import Foundation

/// Координатор данных: online-first с локальным кэшем.
///
/// Чтение: пробуем удалённое хранилище, при успехе обновляем кэш; при ошибке
/// (нет сети) отдаём данные из локального кэша. Запись: сначала в кэш (мгновенный
/// отклик UI), затем в удалённое хранилище.
public actor PlannerRepository {
    private let remote: RemoteStore
    private let local: LocalStore

    public init(remote: RemoteStore, local: LocalStore) {
        self.remote = remote
        self.local = local
    }

    // MARK: - Ученики

    public func students() async -> [Student] {
        do {
            let remoteStudents = try await remote.fetchStudents()
            try? await local.saveStudents(remoteStudents)
            return remoteStudents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            let cached = (try? await local.loadStudents()) ?? []
            return cached.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    @discardableResult
    public func saveStudent(_ student: Student) async -> Bool {
        try? await local.upsertStudent(student)
        do {
            try await remote.upsertStudent(student)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func deleteStudent(id: UUID) async -> Bool {
        try? await local.deleteStudent(id: id)
        do {
            try await remote.deleteStudent(id: id)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Уроки

    public func lessons(in range: DateRange) async -> [Lesson] {
        do {
            let remoteLessons = try await remote.fetchLessons(in: range)
            try? await local.saveLessons(remoteLessons)
            return remoteLessons.sorted { $0.startAt < $1.startAt }
        } catch {
            let cached = (try? await local.loadLessons()) ?? []
            return CalendarRange.lessons(cached, in: range).sorted { $0.startAt < $1.startAt }
        }
    }

    @discardableResult
    public func saveLesson(_ lesson: Lesson) async -> Bool {
        try? await local.upsertLesson(lesson)
        do {
            try await remote.upsertLesson(lesson)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func deleteLesson(id: UUID) async -> Bool {
        try? await local.deleteLesson(id: id)
        do {
            try await remote.deleteLesson(id: id)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Личные задачи (Планы)

    public func tasks(in range: DateRange) async -> [PersonalTask] {
        do {
            let remoteTasks = try await remote.fetchTasks(in: range)
            try? await local.saveTasks(remoteTasks)
            return remoteTasks.sorted { $0.scheduledAt < $1.scheduledAt }
        } catch {
            let cached = (try? await local.loadTasks()) ?? []
            return CalendarRange.tasks(cached, in: range).sorted { $0.scheduledAt < $1.scheduledAt }
        }
    }

    @discardableResult
    public func saveTask(_ task: PersonalTask) async -> Bool {
        try? await local.upsertTask(task)
        do {
            try await remote.upsertTask(task)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func deleteTask(id: UUID) async -> Bool {
        try? await local.deleteTask(id: id)
        do {
            try await remote.deleteTask(id: id)
            return true
        } catch {
            return false
        }
    }
}
