import Foundation

/// Доменная модель урока.
public struct Lesson: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var studentId: UUID
    /// Абсолютное время начала урока.
    public var startAt: Date
    /// Длительность урока в минутах.
    public var durationMinutes: Int
    /// Отметка "Занятие оплачено".
    public var isPaid: Bool
    public var note: String?
    /// Серия еженедельных повторений, в которую входит занятие; `nil` — разовое.
    public var seriesId: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        studentId: UUID,
        startAt: Date,
        durationMinutes: Int = 60,
        isPaid: Bool = false,
        note: String? = nil,
        seriesId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.studentId = studentId
        self.startAt = startAt
        self.durationMinutes = max(LessonScheduling.minimumDurationMinutes, durationMinutes)
        self.isPaid = isPaid
        self.note = note
        self.seriesId = seriesId
        self.createdAt = createdAt
    }

    /// Отметка «повторяется каждую неделю».
    public var repeatsWeekly: Bool { seriesId != nil }

    /// Время окончания урока.
    public var endAt: Date {
        startAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }
}
