import Foundation
import SwiftData
import PlannerCore

/// Локальный кэш поверх SwiftData. Изолирован как actor через ModelActor.
@ModelActor
actor SwiftDataLocalStore: LocalStore {

    // MARK: - Ученики

    func loadStudents() async throws -> [Student] {
        let descriptor = FetchDescriptor<CachedStudent>()
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func saveStudents(_ students: [Student]) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<CachedStudent>())
        let incomingIds = Set(students.map(\.id))

        for stale in existing where !incomingIds.contains(stale.id) {
            modelContext.delete(stale)
        }
        for student in students {
            try upsertStudentInternal(student, existing: existing)
        }
        try modelContext.save()
    }

    func upsertStudent(_ student: Student) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<CachedStudent>())
        try upsertStudentInternal(student, existing: existing)
        try modelContext.save()
    }

    func deleteStudent(id: UUID) async throws {
        let descriptor = FetchDescriptor<CachedStudent>(predicate: #Predicate { $0.id == id })
        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    private func upsertStudentInternal(_ student: Student, existing: [CachedStudent]) throws {
        if let match = existing.first(where: { $0.id == student.id }) {
            match.apply(student)
        } else {
            modelContext.insert(CachedStudent(student))
        }
    }

    // MARK: - Уроки

    func loadLessons() async throws -> [Lesson] {
        let descriptor = FetchDescriptor<CachedLesson>()
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func saveLessons(_ lessons: [Lesson]) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<CachedLesson>())
        for lesson in lessons {
            try upsertLessonInternal(lesson, existing: existing)
        }
        try modelContext.save()
    }

    func upsertLesson(_ lesson: Lesson) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<CachedLesson>())
        try upsertLessonInternal(lesson, existing: existing)
        try modelContext.save()
    }

    func deleteLesson(id: UUID) async throws {
        let descriptor = FetchDescriptor<CachedLesson>(predicate: #Predicate { $0.id == id })
        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    private func upsertLessonInternal(_ lesson: Lesson, existing: [CachedLesson]) throws {
        if let match = existing.first(where: { $0.id == lesson.id }) {
            match.apply(lesson)
        } else {
            modelContext.insert(CachedLesson(lesson))
        }
    }

    // MARK: - Личные задачи (Планы)

    func loadTasks() async throws -> [PersonalTask] {
        let descriptor = FetchDescriptor<CachedPersonalTask>()
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func saveTasks(_ tasks: [PersonalTask]) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<CachedPersonalTask>())
        for task in tasks {
            try upsertTaskInternal(task, existing: existing)
        }
        try modelContext.save()
    }

    func upsertTask(_ task: PersonalTask) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<CachedPersonalTask>())
        try upsertTaskInternal(task, existing: existing)
        try modelContext.save()
    }

    func deleteTask(id: UUID) async throws {
        let descriptor = FetchDescriptor<CachedPersonalTask>(predicate: #Predicate { $0.id == id })
        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    private func upsertTaskInternal(_ task: PersonalTask, existing: [CachedPersonalTask]) throws {
        if let match = existing.first(where: { $0.id == task.id }) {
            match.apply(task)
        } else {
            modelContext.insert(CachedPersonalTask(task))
        }
    }
}
