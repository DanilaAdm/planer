import Foundation
import PlannerCore
import Supabase

/// Реализация RemoteStore поверх Supabase (PostgreSQL + PostgREST).
final class SupabaseRemoteStore: RemoteStore {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Владелец сохраняемых строк. Сервер всё равно проставит его сам из токена,
    /// но отправлять значение явно надёжнее, чем полагаться на умолчание схемы.
    private var ownerId: UUID? {
        client.auth.currentUser?.id
    }

    // MARK: - Ученики

    func fetchStudents() async throws -> [Student] {
        let rows: [StudentDTO] = try await client
            .from("students")
            .select()
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func upsertStudent(_ student: Student) async throws {
        try await client
            .from("students")
            .upsert(StudentDTO(student, ownerId: ownerId))
            .execute()
    }

    func deleteStudent(id: UUID) async throws {
        try await client
            .from("students")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Уроки

    func fetchLessons(in range: DateRange) async throws -> [Lesson] {
        let start = PlannerCoding.iso8601.string(from: range.start)
        let end = PlannerCoding.iso8601.string(from: range.end)
        let rows: [LessonDTO] = try await client
            .from("lessons")
            .select()
            .gte("start_at", value: start)
            .lt("start_at", value: end)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func upsertLesson(_ lesson: Lesson) async throws {
        try await client
            .from("lessons")
            .upsert(LessonDTO(lesson, ownerId: ownerId))
            .execute()
    }

    func upsertLessons(_ lessons: [Lesson]) async throws {
        guard !lessons.isEmpty else { return }
        try await client
            .from("lessons")
            .upsert(lessons.map { LessonDTO($0, ownerId: ownerId) })
            .execute()
    }

    func deleteLesson(id: UUID) async throws {
        try await client
            .from("lessons")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteLessons(seriesId: UUID, after date: Date) async throws {
        try await client
            .from("lessons")
            .delete()
            .eq("series_id", value: seriesId.uuidString)
            .gt("start_at", value: PlannerCoding.iso8601.string(from: date))
            .execute()
    }

    // MARK: - Личные задачи (Планы)

    func fetchTasks(in range: DateRange) async throws -> [PersonalTask] {
        let start = PlannerCoding.iso8601.string(from: range.start)
        let end = PlannerCoding.iso8601.string(from: range.end)
        let rows: [PersonalTaskDTO] = try await client
            .from("personal_tasks")
            .select()
            .gte("scheduled_at", value: start)
            .lt("scheduled_at", value: end)
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func upsertTask(_ task: PersonalTask) async throws {
        try await client
            .from("personal_tasks")
            .upsert(PersonalTaskDTO(task, ownerId: ownerId))
            .execute()
    }

    func deleteTask(id: UUID) async throws {
        try await client
            .from("personal_tasks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Заметки недели

    func fetchWeekNotes(weekStart: Date) async throws -> [WeekNote] {
        let rows: [WeekNoteDTO] = try await client
            .from("week_notes")
            .select()
            .eq("week_start", value: WeekNoteDTO.dayKey(from: weekStart))
            .execute()
            .value
        return rows.map { $0.toDomain() }
    }

    func upsertWeekNote(_ note: WeekNote) async throws {
        try await client
            .from("week_notes")
            .upsert(WeekNoteDTO(note, ownerId: ownerId))
            .execute()
    }

    func deleteWeekNote(id: UUID) async throws {
        try await client
            .from("week_notes")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
