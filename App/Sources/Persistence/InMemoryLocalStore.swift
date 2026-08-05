import Foundation
import PlannerCore

/// Кэш в памяти для демо-режима и UI-тестов.
///
/// Без него демонстрационные ученики и уроки попадали бы в настоящую базу
/// устройства через общий репозиторий, и после выхода из демо реальный
/// пользователь видел бы их офлайн как свои данные.
actor InMemoryLocalStore: LocalStore {
    private var students: [UUID: Student] = [:]
    private var lessons: [UUID: Lesson] = [:]
    private var tasks: [UUID: PersonalTask] = [:]

    func clearAll() async throws {
        students.removeAll()
        lessons.removeAll()
        tasks.removeAll()
    }

    // MARK: - Ученики

    func loadStudents() async throws -> [Student] { Array(students.values) }

    func saveStudents(_ students: [Student]) async throws {
        self.students = Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
    }

    func upsertStudent(_ student: Student) async throws { students[student.id] = student }
    func deleteStudent(id: UUID) async throws { students[id] = nil }

    // MARK: - Уроки

    func loadLessons() async throws -> [Lesson] { Array(lessons.values) }

    func saveLessons(_ lessons: [Lesson]) async throws {
        for lesson in lessons { self.lessons[lesson.id] = lesson }
    }

    func upsertLesson(_ lesson: Lesson) async throws { lessons[lesson.id] = lesson }
    func deleteLesson(id: UUID) async throws { lessons[id] = nil }

    // MARK: - Личные задачи (Планы)

    func loadTasks() async throws -> [PersonalTask] { Array(tasks.values) }

    func saveTasks(_ tasks: [PersonalTask]) async throws {
        for task in tasks { self.tasks[task.id] = task }
    }

    func upsertTask(_ task: PersonalTask) async throws { tasks[task.id] = task }
    func deleteTask(id: UUID) async throws { tasks[id] = nil }
}
