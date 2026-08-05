import Foundation

/// Личная задача из раздела «Планы» — в отличие от урока не привязана к ученику.
public struct PersonalTask: Identifiable, Hashable, Codable, Sendable {
    /// Цвет по умолчанию для задач-планов (отличается от палитры учеников).
    public static let defaultColorHex = "#8A94B8"

    public var id: UUID
    /// Название задачи (что нужно сделать).
    public var title: String
    /// День и время, на которые запланирована задача.
    public var scheduledAt: Date
    /// Дополнительная заметка/детали.
    public var note: String?
    /// Отметка «выполнено».
    public var isDone: Bool
    /// Цвет метки задачи в формате "#RRGGBB".
    public var colorHex: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        scheduledAt: Date,
        note: String? = nil,
        isDone: Bool = false,
        colorHex: String = PersonalTask.defaultColorHex,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.scheduledAt = scheduledAt
        self.note = note
        self.isDone = isDone
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
