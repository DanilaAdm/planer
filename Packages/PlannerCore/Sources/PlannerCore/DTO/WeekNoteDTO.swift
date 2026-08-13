import Foundation

/// DTO заметки недели для обмена с PostgreSQL (snake_case, как в таблице `week_notes`).
///
/// `week_start` — календарная метка недели, а не момент времени, поэтому колонка
/// имеет тип `date`, а поле кодируется строкой `yyyy-MM-dd`. Хранить его как
/// `timestamptz` нельзя: полночь понедельника в другом часовом поясе попала бы в
/// соседнюю неделю, и заметки «пропали» бы при поездке.
public struct WeekNoteDTO: Codable, Sendable, Equatable {
    public var id: UUID
    /// Владелец записи; сервер перезаписывает поле значением из токена.
    public var owner_id: UUID?
    public var week_start: String
    public var text: String
    public var created_at: Date

    public init(
        id: UUID,
        owner_id: UUID? = nil,
        week_start: String,
        text: String,
        created_at: Date
    ) {
        self.id = id
        self.owner_id = owner_id
        self.week_start = week_start
        self.text = text
        self.created_at = created_at
    }

    public init(_ note: WeekNote, ownerId: UUID? = nil) {
        self.init(
            id: note.id,
            owner_id: ownerId,
            week_start: Self.dayKey(from: note.weekStart),
            text: note.text,
            created_at: note.createdAt
        )
    }

    // MARK: - Ключ недели

    /// Формат колонки `date` в PostgreSQL.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Дата начала недели в виде ключа `yyyy-MM-dd`.
    public static func dayKey(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// Разобрать ключ `yyyy-MM-dd` в полночь соответствующего дня.
    public static func date(fromDayKey key: String) -> Date? {
        dayFormatter.date(from: key)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, owner_id, week_start, text, created_at
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        owner_id = try container.decodeIfPresent(UUID.self, forKey: .owner_id)
        week_start = try container.decode(String.self, forKey: .week_start)
        text = try container.decode(String.self, forKey: .text)
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
    }

    /// `created_at` не отправляется, чтобы не перезаписывать дату создания при
    /// каждом сохранении.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(owner_id, forKey: .owner_id)
        try container.encode(week_start, forKey: .week_start)
        try container.encode(text, forKey: .text)
    }

    public func toDomain() -> WeekNote {
        WeekNote(
            id: id,
            weekStart: Self.date(fromDayKey: week_start) ?? Date(),
            text: text,
            createdAt: created_at
        )
    }
}
