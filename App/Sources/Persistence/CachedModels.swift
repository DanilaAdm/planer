import Foundation
import SwiftData
import PlannerCore

/// Локальная (кэш) модель ученика для офлайн-чтения.
@Model
final class CachedStudent {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var pricePerLesson: Decimal
    var workFormatRaw: String
    var googleDocURLString: String?
    var paidLessonsTotal: Int
    var lessonsUsed: Int
    var createdAt: Date

    init(_ student: Student) {
        self.id = student.id
        self.name = student.name
        self.colorHex = student.colorHex
        self.pricePerLesson = student.pricePerLesson
        self.workFormatRaw = student.workFormat.rawValue
        self.googleDocURLString = student.googleDocURL?.absoluteString
        self.paidLessonsTotal = student.paidLessonsTotal
        self.lessonsUsed = student.lessonsUsed
        self.createdAt = student.createdAt
    }

    func apply(_ student: Student) {
        name = student.name
        colorHex = student.colorHex
        pricePerLesson = student.pricePerLesson
        workFormatRaw = student.workFormat.rawValue
        googleDocURLString = student.googleDocURL?.absoluteString
        paidLessonsTotal = student.paidLessonsTotal
        lessonsUsed = student.lessonsUsed
        createdAt = student.createdAt
    }

    func toDomain() -> Student {
        Student(
            id: id,
            name: name,
            colorHex: colorHex,
            pricePerLesson: pricePerLesson,
            workFormat: WorkFormat(rawValue: workFormatRaw) ?? .postpay,
            googleDocURL: googleDocURLString.flatMap(URL.init(string:)),
            paidLessonsTotal: paidLessonsTotal,
            lessonsUsed: lessonsUsed,
            createdAt: createdAt
        )
    }
}

/// Локальная (кэш) модель урока для офлайн-чтения.
@Model
final class CachedLesson {
    @Attribute(.unique) var id: UUID
    var studentId: UUID
    var startAt: Date
    var durationMinutes: Int
    var isPaid: Bool
    var note: String?
    var seriesId: UUID?
    var createdAt: Date

    init(_ lesson: Lesson) {
        self.id = lesson.id
        self.studentId = lesson.studentId
        self.startAt = lesson.startAt
        self.durationMinutes = lesson.durationMinutes
        self.isPaid = lesson.isPaid
        self.note = lesson.note
        self.seriesId = lesson.seriesId
        self.createdAt = lesson.createdAt
    }

    func apply(_ lesson: Lesson) {
        studentId = lesson.studentId
        startAt = lesson.startAt
        durationMinutes = lesson.durationMinutes
        isPaid = lesson.isPaid
        note = lesson.note
        seriesId = lesson.seriesId
        createdAt = lesson.createdAt
    }

    func toDomain() -> Lesson {
        Lesson(
            id: id,
            studentId: studentId,
            startAt: startAt,
            durationMinutes: durationMinutes,
            isPaid: isPaid,
            note: note,
            seriesId: seriesId,
            createdAt: createdAt
        )
    }
}

/// Изменение, которое не удалось отправить на сервер.
///
/// Живёт в той же базе, что и кэш, но переживает его очистку: правки, сделанные
/// без интернета, должны уехать на сервер даже после смены аккаунта и обратно.
@Model
final class PendingChange {
    @Attribute(.unique) var id: UUID
    var ownerId: UUID
    var kindRaw: String
    var entityId: UUID
    var payload: Data?
    var createdAt: Date

    init(_ operation: PendingOperation) {
        self.id = operation.id
        self.ownerId = operation.ownerId
        self.kindRaw = operation.kind.rawValue
        self.entityId = operation.entityId
        self.payload = operation.payload
        self.createdAt = operation.createdAt
    }

    /// `nil`, если в базе оказался неизвестный вид операции (например, запись
    /// оставила более новая версия приложения).
    func toDomain() -> PendingOperation? {
        guard let kind = PendingOperation.Kind(rawValue: kindRaw) else { return nil }
        return PendingOperation(
            id: id,
            ownerId: ownerId,
            kind: kind,
            entityId: entityId,
            payload: payload,
            createdAt: createdAt
        )
    }
}

/// Локальная (кэш) модель личной задачи (раздел «Планы») для офлайн-чтения.
@Model
final class CachedPersonalTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var scheduledAt: Date
    var note: String?
    var isDone: Bool
    var colorHex: String
    var createdAt: Date

    init(_ task: PersonalTask) {
        self.id = task.id
        self.title = task.title
        self.scheduledAt = task.scheduledAt
        self.note = task.note
        self.isDone = task.isDone
        self.colorHex = task.colorHex
        self.createdAt = task.createdAt
    }

    func apply(_ task: PersonalTask) {
        title = task.title
        scheduledAt = task.scheduledAt
        note = task.note
        isDone = task.isDone
        colorHex = task.colorHex
        createdAt = task.createdAt
    }

    func toDomain() -> PersonalTask {
        PersonalTask(
            id: id,
            title: title,
            scheduledAt: scheduledAt,
            note: note,
            isDone: isDone,
            colorHex: colorHex,
            createdAt: createdAt
        )
    }
}

/// Локальная (кэш) модель заметки недели для офлайн-чтения.
@Model
final class CachedWeekNote {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var text: String
    var createdAt: Date

    init(_ note: WeekNote) {
        self.id = note.id
        self.weekStart = note.weekStart
        self.text = note.text
        self.createdAt = note.createdAt
    }

    func apply(_ note: WeekNote) {
        weekStart = note.weekStart
        text = note.text
        createdAt = note.createdAt
    }

    func toDomain() -> WeekNote {
        WeekNote(id: id, weekStart: weekStart, text: text, createdAt: createdAt)
    }
}
