import Foundation
import SwiftData
import PlannerCore

/// Локальный кэш и очередь досылки поверх SwiftData.
/// Изолирован как actor через ModelActor.
@ModelActor
actor SwiftDataLocalStore: LocalStore {

    // MARK: - Очистка

    /// Стереть весь кэш, не трогая очередь неотправленных изменений.
    func clearAll() async throws {
        try modelContext.delete(model: CachedStudent.self)
        try modelContext.delete(model: CachedLesson.self)
        try modelContext.delete(model: CachedPersonalTask.self)
        try modelContext.delete(model: CachedWeekNote.self)
        try modelContext.save()
    }

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

    func deleteLessons(seriesId: UUID, after date: Date) async throws {
        let descriptor = FetchDescriptor<CachedLesson>(
            predicate: #Predicate { $0.seriesId == seriesId && $0.startAt > date }
        )
        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    func deleteLessons(studentId: UUID) async throws {
        let descriptor = FetchDescriptor<CachedLesson>(predicate: #Predicate { $0.studentId == studentId })
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

    // MARK: - Заметки недели

    func loadWeekNotes() async throws -> [WeekNote] {
        let descriptor = FetchDescriptor<CachedWeekNote>()
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func saveWeekNotes(_ notes: [WeekNote]) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<CachedWeekNote>())
        for note in notes {
            try upsertWeekNoteInternal(note, existing: existing)
        }
        try modelContext.save()
    }

    func upsertWeekNote(_ note: WeekNote) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<CachedWeekNote>())
        try upsertWeekNoteInternal(note, existing: existing)
        try modelContext.save()
    }

    func deleteWeekNote(id: UUID) async throws {
        let descriptor = FetchDescriptor<CachedWeekNote>(predicate: #Predicate { $0.id == id })
        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    private func upsertWeekNoteInternal(_ note: WeekNote, existing: [CachedWeekNote]) throws {
        if let match = existing.first(where: { $0.id == note.id }) {
            match.apply(note)
        } else {
            modelContext.insert(CachedWeekNote(note))
        }
    }
}

// MARK: - Очередь неотправленных изменений

extension SwiftDataLocalStore: OutboxStore {
    func enqueue(_ operation: PendingOperation) async throws {
        // На сервер должно уехать итоговое состояние сущности, а не вся история
        // правок, поэтому прежние операции по тому же объекту вытесняются.
        let owner = operation.ownerId
        let entity = operation.entityId
        let descriptor = FetchDescriptor<PendingChange>(
            predicate: #Predicate { $0.ownerId == owner && $0.entityId == entity }
        )
        for stale in try modelContext.fetch(descriptor) {
            modelContext.delete(stale)
        }
        modelContext.insert(PendingChange(operation))
        try modelContext.save()
    }

    func pending(ownerId: UUID) async throws -> [PendingOperation] {
        let descriptor = FetchDescriptor<PendingChange>(
            predicate: #Predicate { $0.ownerId == ownerId }
        )
        return try modelContext.fetch(descriptor)
            .compactMap { $0.toDomain() }
            .sorted(by: PendingOperation.sendOrder)
    }

    func remove(id: UUID) async throws {
        let descriptor = FetchDescriptor<PendingChange>(predicate: #Predicate { $0.id == id })
        for item in try modelContext.fetch(descriptor) {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    func removeAll(ownerId: UUID) async throws {
        try modelContext.delete(
            model: PendingChange.self,
            where: #Predicate { $0.ownerId == ownerId }
        )
        try modelContext.save()
    }
}
