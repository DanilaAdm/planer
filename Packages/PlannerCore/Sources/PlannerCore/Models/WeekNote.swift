import Foundation

/// Заметка недели — строка блока «Заметки» на развороте дневника.
///
/// В отличие от урока и личной задачи не привязана ко времени: она относится к
/// неделе целиком, поэтому ключом служит её начало (понедельник).
public struct WeekNote: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    /// Начало недели (понедельник, 00:00 местного времени), к которой относится заметка.
    public var weekStart: Date
    /// Текст заметки.
    public var text: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        weekStart: Date,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.weekStart = weekStart
        self.text = text
        self.createdAt = createdAt
    }

    /// Ключ недели, содержащей дату.
    ///
    /// Единая нормализация: без неё заметки одной недели получили бы разные
    /// `weekStart` и перестали находиться при следующей загрузке.
    public static func weekStart(containing date: Date, calendar: Calendar = .current) -> Date {
        CalendarRange.week(containing: date, calendar: calendar).start
    }
}
