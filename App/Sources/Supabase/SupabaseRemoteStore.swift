import Foundation
import PlannerCore
import Supabase

/// Реализация RemoteStore поверх Supabase (PostgreSQL + PostgREST).
final class SupabaseRemoteStore: RemoteStore {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
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
            .upsert(StudentDTO(student))
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
            .upsert(LessonDTO(lesson))
            .execute()
    }

    func deleteLesson(id: UUID) async throws {
        try await client
            .from("lessons")
            .delete()
            .eq("id", value: id.uuidString)
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
            .upsert(PersonalTaskDTO(task))
            .execute()
    }

    func deleteTask(id: UUID) async throws {
        try await client
            .from("personal_tasks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
