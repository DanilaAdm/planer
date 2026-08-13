import Foundation

/// Удалённое хранилище (PostgreSQL через Supabase).
public protocol RemoteStore: Sendable {
    func fetchStudents() async throws -> [Student]
    func upsertStudent(_ student: Student) async throws
    func deleteStudent(id: UUID) async throws

    func fetchLessons(in range: DateRange) async throws -> [Lesson]
    func upsertLesson(_ lesson: Lesson) async throws
    /// Сохранить несколько занятий одним обменом: серия еженедельных повторений
    /// раскрывается на год вперёд, и 52 отдельных запроса заметно тормозили бы
    /// сохранение записи.
    func upsertLessons(_ lessons: [Lesson]) async throws
    func deleteLesson(id: UUID) async throws
    /// Убрать повторы серии, начинающиеся позже `date`. Так снятая отметка
    /// «каждую неделю» очищает расписание одним запросом.
    func deleteLessons(seriesId: UUID, after date: Date) async throws

    func fetchTasks(in range: DateRange) async throws -> [PersonalTask]
    func upsertTask(_ task: PersonalTask) async throws
    func deleteTask(id: UUID) async throws

    func fetchWeekNotes(weekStart: Date) async throws -> [WeekNote]
    func upsertWeekNote(_ note: WeekNote) async throws
    func deleteWeekNote(id: UUID) async throws
}

/// Локальный кэш (SwiftData) для офлайн-чтения.
public protocol LocalStore: Sendable {
    /// Полностью очистить кэш. Вызывается при входе под другим аккаунтом:
    /// иначе офлайн-чтение показало бы данные предыдущего пользователя.
    func clearAll() async throws

    func loadStudents() async throws -> [Student]
    func saveStudents(_ students: [Student]) async throws
    func upsertStudent(_ student: Student) async throws
    func deleteStudent(id: UUID) async throws

    func loadLessons() async throws -> [Lesson]
    func saveLessons(_ lessons: [Lesson]) async throws
    func upsertLesson(_ lesson: Lesson) async throws
    func deleteLesson(id: UUID) async throws
    /// Убрать повторы серии, начинающиеся позже `date`.
    func deleteLessons(seriesId: UUID, after date: Date) async throws
    /// Убрать из кэша занятия удалённого ученика: на сервере их снимает каскад
    /// внешнего ключа, а офлайн они иначе остались бы в расписании.
    func deleteLessons(studentId: UUID) async throws

    func loadTasks() async throws -> [PersonalTask]
    func saveTasks(_ tasks: [PersonalTask]) async throws
    func upsertTask(_ task: PersonalTask) async throws
    func deleteTask(id: UUID) async throws

    func loadWeekNotes() async throws -> [WeekNote]
    func saveWeekNotes(_ notes: [WeekNote]) async throws
    func upsertWeekNote(_ note: WeekNote) async throws
    func deleteWeekNote(id: UUID) async throws
}
