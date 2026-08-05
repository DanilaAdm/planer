import Foundation

/// DTO личной задачи для обмена с PostgreSQL (snake_case, как в таблице `personal_tasks`).
public struct PersonalTaskDTO: Codable, Sendable, Equatable {
    public var id: UUID
    /// Владелец записи; сервер перезаписывает поле значением из токена.
    public var owner_id: UUID?
    public var title: String
    public var scheduled_at: Date
    public var note: String?
    public var is_done: Bool
    public var color_hex: String
    public var created_at: Date

    public init(
        id: UUID,
        owner_id: UUID? = nil,
        title: String,
        scheduled_at: Date,
        note: String?,
        is_done: Bool,
        color_hex: String,
        created_at: Date
    ) {
        self.id = id
        self.owner_id = owner_id
        self.title = title
        self.scheduled_at = scheduled_at
        self.note = note
        self.is_done = is_done
        self.color_hex = color_hex
        self.created_at = created_at
    }

    public init(_ task: PersonalTask, ownerId: UUID? = nil) {
        self.init(
            id: task.id,
            owner_id: ownerId,
            title: task.title,
            scheduled_at: task.scheduledAt,
            note: task.note,
            is_done: task.isDone,
            color_hex: task.colorHex,
            created_at: task.createdAt
        )
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, owner_id, title, scheduled_at, note, is_done, color_hex, created_at
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        owner_id = try container.decodeIfPresent(UUID.self, forKey: .owner_id)
        title = try container.decode(String.self, forKey: .title)
        scheduled_at = try container.decode(Date.self, forKey: .scheduled_at)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        is_done = try container.decode(Bool.self, forKey: .is_done)
        color_hex = try container.decode(String.self, forKey: .color_hex)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
    }

    /// `note` кодируется явно, чтобы стёртая заметка уезжала на сервер как
    /// `null`; `created_at` не отправляется, чтобы не перезаписывать дату
    /// создания при каждом сохранении.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(owner_id, forKey: .owner_id)
        try container.encode(title, forKey: .title)
        try container.encode(scheduled_at, forKey: .scheduled_at)
        try container.encode(note, forKey: .note)
        try container.encode(is_done, forKey: .is_done)
        try container.encode(color_hex, forKey: .color_hex)
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
