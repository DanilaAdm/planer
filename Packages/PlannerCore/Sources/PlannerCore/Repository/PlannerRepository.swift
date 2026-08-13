import Foundation

/// Координатор данных: online-first с локальным кэшем и очередью досылки.
///
/// Чтение: пробуем удалённое хранилище, при успехе обновляем кэш; при ошибке
/// (нет сети) отдаём данные из локального кэша. Запись: сначала в кэш (мгновенный
/// отклик UI), затем на сервер; если сервер недоступен, изменение встаёт в
/// очередь и уезжает при следующей удачной связи.
public actor PlannerRepository {
    private let remote: RemoteStore
    private let local: LocalStore
    private let outbox: OutboxStore
    /// Владелец данных: им помечаются операции в очереди.
    private let ownerId: UUID

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Удался ли последний обмен с сервером.
    ///
    /// Без этого признака недоступный сервер неотличим от пустой базы: чтение
    /// молча возвращает кэш, и на новом устройстве пользователь видит пустой
    /// планер, будто данные пропали.
    private var serverReachable = true

    public init(remote: RemoteStore, local: LocalStore, outbox: OutboxStore, ownerId: UUID) {
        self.remote = remote
        self.local = local
        self.outbox = outbox
        self.ownerId = ownerId
    }

    /// Вариант без постоянной очереди — для демо-режима и тестов, где
    /// переживать перезапуск приложения нечему.
    public init(remote: RemoteStore, local: LocalStore) {
        self.init(
            remote: remote,
            local: local,
            outbox: InMemoryOutboxStore(),
            ownerId: UUID()
        )
    }

    /// Показанные данные пришли с сервера, а не только из кэша.
    ///
    /// Пока `false`, пустой список нельзя трактовать как «данных нет» — их
    /// просто не удалось загрузить.
    public func isServerReachable() -> Bool { serverReachable }

    // MARK: - Ученики

    public func students() async -> [Student] {
        do {
            let remoteStudents = try await remote.fetchStudents()
            serverReachable = true
            try? await local.saveStudents(remoteStudents)
            return remoteStudents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            serverReachable = false
            let cached = (try? await local.loadStudents()) ?? []
            return cached.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    @discardableResult
    public func saveStudent(_ student: Student) async -> Bool {
        try? await local.upsertStudent(student)
        do {
            try await remote.upsertStudent(student)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            await enqueue(.upsertStudent, entityId: student.id, value: student)
            return false
        }
    }

    @discardableResult
    public func deleteStudent(id: UUID) async -> Bool {
        try? await local.deleteStudent(id: id)
        // Занятия ученика уходят вместе с ним: на сервере это делает каскад
        // внешнего ключа, в кэше — мы сами, иначе офлайн они остались бы в
        // расписании как записи без имени.
        try? await local.deleteLessons(studentId: id)
        do {
            try await remote.deleteStudent(id: id)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            await enqueue(.deleteStudent, entityId: id, value: Student?.none)
            return false
        }
    }

    // MARK: - Уроки

    public func lessons(in range: DateRange) async -> [Lesson] {
        do {
            let remoteLessons = try await remote.fetchLessons(in: range)
            serverReachable = true
            try? await local.saveLessons(remoteLessons)
            return remoteLessons.sorted { $0.startAt < $1.startAt }
        } catch {
            serverReachable = false
            let cached = (try? await local.loadLessons()) ?? []
            return CalendarRange.lessons(cached, in: range).sorted { $0.startAt < $1.startAt }
        }
    }

    @discardableResult
    public func saveLesson(_ lesson: Lesson) async -> Bool {
        try? await local.upsertLesson(lesson)
        do {
            try await remote.upsertLesson(lesson)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            await enqueue(.upsertLesson, entityId: lesson.id, value: lesson)
            return false
        }
    }

    /// Сохранить серию еженедельных повторений одним обменом с сервером.
    @discardableResult
    public func saveLessons(_ lessons: [Lesson]) async -> Bool {
        guard !lessons.isEmpty else { return true }
        try? await local.saveLessons(lessons)
        do {
            try await remote.upsertLessons(lessons)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            // В очередь занятия встают по одному: досылка умеет отправлять
            // только отдельные сущности, зато порядок и вытеснение работают
            // так же, как для любой другой правки.
            for lesson in lessons {
                await enqueue(.upsertLesson, entityId: lesson.id, value: lesson)
            }
            return false
        }
    }

    @discardableResult
    public func deleteLesson(id: UUID) async -> Bool {
        try? await local.deleteLesson(id: id)
        do {
            try await remote.deleteLesson(id: id)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            await enqueue(.deleteLesson, entityId: id, value: Lesson?.none)
            return false
        }
    }

    /// Снять повторы серии, начинающиеся позже `date`: отметку «каждую неделю»
    /// выключили, и со следующей недели занятия в расписании быть не должно.
    @discardableResult
    public func cancelLessonSeries(seriesId: UUID, after date: Date) async -> Bool {
        try? await local.deleteLessons(seriesId: seriesId, after: date)
        do {
            try await remote.deleteLessons(seriesId: seriesId, after: date)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            await enqueue(.cancelLessonSeries, entityId: seriesId, value: LessonSeriesCancellation(after: date))
            return false
        }
    }

    // MARK: - Личные задачи (Планы)

    public func tasks(in range: DateRange) async -> [PersonalTask] {
        do {
            let remoteTasks = try await remote.fetchTasks(in: range)
            serverReachable = true
            try? await local.saveTasks(remoteTasks)
            return remoteTasks.sorted { $0.scheduledAt < $1.scheduledAt }
        } catch {
            serverReachable = false
            let cached = (try? await local.loadTasks()) ?? []
            return CalendarRange.tasks(cached, in: range).sorted { $0.scheduledAt < $1.scheduledAt }
        }
    }

    @discardableResult
    public func saveTask(_ task: PersonalTask) async -> Bool {
        try? await local.upsertTask(task)
        do {
            try await remote.upsertTask(task)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            await enqueue(.upsertTask, entityId: task.id, value: task)
            return false
        }
    }

    @discardableResult
    public func deleteTask(id: UUID) async -> Bool {
        try? await local.deleteTask(id: id)
        do {
            try await remote.deleteTask(id: id)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            await enqueue(.deleteTask, entityId: id, value: PersonalTask?.none)
            return false
        }
    }

    // MARK: - Заметки недели

    public func weekNotes(weekStart: Date, calendar: Calendar = .current) async -> [WeekNote] {
        do {
            let remoteNotes = try await remote.fetchWeekNotes(weekStart: weekStart)
            serverReachable = true
            try? await local.saveWeekNotes(remoteNotes)
            return remoteNotes.sorted { $0.createdAt < $1.createdAt }
        } catch {
            serverReachable = false
            let cached = (try? await local.loadWeekNotes()) ?? []
            return CalendarRange.weekNotes(cached, weekStart: weekStart, calendar: calendar)
                .sorted { $0.createdAt < $1.createdAt }
        }
    }

    @discardableResult
    public func saveWeekNote(_ note: WeekNote) async -> Bool {
        try? await local.upsertWeekNote(note)
        do {
            try await remote.upsertWeekNote(note)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            await enqueue(.upsertWeekNote, entityId: note.id, value: note)
            return false
        }
    }

    @discardableResult
    public func deleteWeekNote(id: UUID) async -> Bool {
        try? await local.deleteWeekNote(id: id)
        do {
            try await remote.deleteWeekNote(id: id)
            serverReachable = true
            return true
        } catch {
            serverReachable = false
            await enqueue(.deleteWeekNote, entityId: id, value: WeekNote?.none)
            return false
        }
    }

    // MARK: - Очередь досылки

    /// Сколько изменений ждут отправки на сервер.
    public func pendingCount() async -> Int {
        ((try? await outbox.pending(ownerId: ownerId)) ?? []).count
    }

    /// Отправить накопленные изменения.
    ///
    /// Останавливается на первой же неудаче: если связь снова пропала, нет
    /// смысла перебирать остаток очереди, а порядок операций важно сохранить.
    /// Возвращает `true`, когда очередь опустела.
    ///
    /// Пустая очередь не означает, что сервер на связи: к нему в этом случае
    /// вовсе не обращались, поэтому признак доступности остаётся прежним.
    @discardableResult
    public func flushPending() async -> Bool {
        guard let operations = try? await outbox.pending(ownerId: ownerId), !operations.isEmpty else {
            return true
        }
        for operation in operations {
            do {
                try await send(operation)
                serverReachable = true
                try? await outbox.remove(id: operation.id)
            } catch {
                // Операцию оставляем в очереди — повторим при следующей попытке.
                serverReachable = false
                return false
            }
        }
        return true
    }

    /// Поставить в очередь всё содержимое локального кэша и отправить.
    ///
    /// Аварийное восстановление на случай, когда данные есть на устройстве, но
    /// не доехали до сервера и следа в очереди не оставили — например, их завела
    /// версия приложения без очереди досылки. Иначе их пришлось бы вводить заново.
    ///
    /// Запись идёт через `upsert`, поэтому повторный запуск ничего не портит.
    @discardableResult
    public func uploadLocalCache() async -> Bool {
        for student in (try? await local.loadStudents()) ?? [] {
            await enqueue(.upsertStudent, entityId: student.id, value: student)
        }
        for lesson in (try? await local.loadLessons()) ?? [] {
            await enqueue(.upsertLesson, entityId: lesson.id, value: lesson)
        }
        for task in (try? await local.loadTasks()) ?? [] {
            await enqueue(.upsertTask, entityId: task.id, value: task)
        }
        for note in (try? await local.loadWeekNotes()) ?? [] {
            await enqueue(.upsertWeekNote, entityId: note.id, value: note)
        }
        return await flushPending()
    }

    private func send(_ operation: PendingOperation) async throws {
        switch operation.kind {
        case .upsertStudent:
            guard let student = decode(Student.self, from: operation.payload) else { return }
            try await remote.upsertStudent(student)
        case .deleteStudent:
            try await remote.deleteStudent(id: operation.entityId)
        case .upsertLesson:
            guard let lesson = decode(Lesson.self, from: operation.payload) else { return }
            try await remote.upsertLesson(lesson)
        case .deleteLesson:
            try await remote.deleteLesson(id: operation.entityId)
        case .cancelLessonSeries:
            guard let cancellation = decode(LessonSeriesCancellation.self, from: operation.payload) else { return }
            try await remote.deleteLessons(seriesId: operation.entityId, after: cancellation.after)
        case .upsertTask:
            guard let task = decode(PersonalTask.self, from: operation.payload) else { return }
            try await remote.upsertTask(task)
        case .deleteTask:
            try await remote.deleteTask(id: operation.entityId)
        case .upsertWeekNote:
            guard let note = decode(WeekNote.self, from: operation.payload) else { return }
            try await remote.upsertWeekNote(note)
        case .deleteWeekNote:
            try await remote.deleteWeekNote(id: operation.entityId)
        }
    }

    private func enqueue<T: Encodable>(_ kind: PendingOperation.Kind, entityId: UUID, value: T?) async {
        let payload = value.flatMap { try? encoder.encode($0) }
        let operation = PendingOperation(
            ownerId: ownerId,
            kind: kind,
            entityId: entityId,
            payload: payload
        )
        try? await outbox.enqueue(operation)
    }

    /// Испорченная запись очереди не должна блокировать отправку остальных,
    /// поэтому неудачное декодирование считается выполненной операцией.
    private func decode<T: Decodable>(_ type: T.Type, from payload: Data?) -> T? {
        guard let payload else { return nil }
        return try? decoder.decode(type, from: payload)
    }
}
