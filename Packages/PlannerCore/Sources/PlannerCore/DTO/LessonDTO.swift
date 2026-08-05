import Foundation

/// DTO урока для обмена с PostgreSQL (snake_case, как в таблице `lessons`).
public struct LessonDTO: Codable, Sendable, Equatable {
    public var id: UUID
    public var student_id: UUID
    public var start_at: Date
    public var duration_min: Int
    public var is_paid: Bool
    public var note: String?
    public var created_at: Date

    public init(
        id: UUID,
        student_id: UUID,
        start_at: Date,
        duration_min: Int,
        is_paid: Bool,
        note: String?,
        created_at: Date
    ) {
        self.id = id
        self.student_id = student_id
        self.start_at = start_at
        self.duration_min = duration_min
        self.is_paid = is_paid
        self.note = note
        self.created_at = created_at
    }

    public init(_ lesson: Lesson) {
        self.init(
            id: lesson.id,
            student_id: lesson.studentId,
            start_at: lesson.startAt,
            duration_min: lesson.durationMinutes,
            is_paid: lesson.isPaid,
            note: lesson.note,
            created_at: lesson.createdAt
        )
    }

    public func toDomain() -> Lesson {
        Lesson(
            id: id,
            studentId: student_id,
            startAt: start_at,
            durationMinutes: duration_min,
            isPaid: is_paid,
            note: note,
            createdAt: created_at
        )
    }
}
