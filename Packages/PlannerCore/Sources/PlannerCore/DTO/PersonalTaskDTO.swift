import Foundation

/// DTO личной задачи для обмена с PostgreSQL (snake_case, как в таблице `personal_tasks`).
public struct PersonalTaskDTO: Codable, Sendable, Equatable {
    public var id: UUID
    public var title: String
    public var scheduled_at: Date
    public var note: String?
    public var is_done: Bool
    public var color_hex: String
    public var created_at: Date

    public init(
        id: UUID,
        title: String,
        scheduled_at: Date,
        note: String?,
        is_done: Bool,
        color_hex: String,
        created_at: Date
    ) {
        self.id = id
        self.title = title
        self.scheduled_at = scheduled_at
        self.note = note
        self.is_done = is_done
        self.color_hex = color_hex
        self.created_at = created_at
    }

    public init(_ task: PersonalTask) {
        self.init(
            id: task.id,
            title: task.title,
            scheduled_at: task.scheduledAt,
            note: task.note,
            is_done: task.isDone,
            color_hex: task.colorHex,
            created_at: task.createdAt
        )
    }

    public func toDomain() -> PersonalTask {
        PersonalTask(
            id: id,
            title: title,
            scheduledAt: scheduled_at,
            note: note,
            isDone: is_done,
            colorHex: HexColor.normalized(color_hex),
            createdAt: created_at
        )
    }
}
