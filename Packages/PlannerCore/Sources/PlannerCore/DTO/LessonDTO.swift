import Foundation

/// DTO урока для обмена с PostgreSQL (snake_case, как в таблице `lessons`).
public struct LessonDTO: Codable, Sendable, Equatable {
    public var id: UUID
    /// Владелец записи; сервер перезаписывает поле значением из токена.
    public var owner_id: UUID?
    public var student_id: UUID
    public var start_at: Date
    public var duration_min: Int
    public var is_paid: Bool
    public var note: String?
    /// Серия еженедельных повторений; `null` — разовое занятие.
    public var series_id: UUID?
    public var created_at: Date

    public init(
        id: UUID,
        owner_id: UUID? = nil,
        student_id: UUID,
        start_at: Date,
        duration_min: Int,
        is_paid: Bool,
        note: String?,
        series_id: UUID? = nil,
        created_at: Date
    ) {
        self.id = id
        self.owner_id = owner_id
        self.student_id = student_id
        self.start_at = start_at
        self.duration_min = duration_min
        self.is_paid = is_paid
        self.note = note
        self.series_id = series_id
        self.created_at = created_at
    }

    public init(_ lesson: Lesson, ownerId: UUID? = nil) {
        self.init(
            id: lesson.id,
            owner_id: ownerId,
            student_id: lesson.studentId,
            start_at: lesson.startAt,
            duration_min: lesson.durationMinutes,
            is_paid: lesson.isPaid,
            note: lesson.note,
            series_id: lesson.seriesId,
            created_at: lesson.createdAt
        )
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, owner_id, student_id, start_at, duration_min, is_paid, note, series_id, created_at
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        owner_id = try container.decodeIfPresent(UUID.self, forKey: .owner_id)
        student_id = try container.decode(UUID.self, forKey: .student_id)
        start_at = try container.decode(Date.self, forKey: .start_at)
        duration_min = try container.decode(Int.self, forKey: .duration_min)
        is_paid = try container.decode(Bool.self, forKey: .is_paid)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        series_id = try container.decodeIfPresent(UUID.self, forKey: .series_id)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
    }

    /// `note` и `series_id` кодируются явно, чтобы стёртая заметка и снятая
    /// отметка повторения уезжали на сервер как `null`; `created_at` не
    /// отправляется, чтобы не перезаписывать дату создания при каждом сохранении.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(owner_id, forKey: .owner_id)
        try container.encode(student_id, forKey: .student_id)
        try container.encode(start_at, forKey: .start_at)
        try container.encode(duration_min, forKey: .duration_min)
        try container.encode(is_paid, forKey: .is_paid)
        try container.encode(note, forKey: .note)
        try container.encode(series_id, forKey: .series_id)
    }

    public func toDomain() -> Lesson {
        Lesson(
            id: id,
            studentId: student_id,
            startAt: start_at,
            durationMinutes: duration_min,
            isPaid: is_paid,
            note: note,
            seriesId: series_id,
            createdAt: created_at
        )
    }
}
