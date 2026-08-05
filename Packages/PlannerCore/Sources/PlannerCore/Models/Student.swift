import Foundation

/// Доменная модель ученика (без зависимостей от UI/БД).
public struct Student: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    /// Цвет ученика в формате "#RRGGBB".
    public var colorHex: String
    /// Стоимость одного урока.
    public var pricePerLesson: Decimal
    public var workFormat: WorkFormat
    /// Ссылка на шаблон Google-документа (пройденный материал / предстоящие темы).
    public var googleDocURL: URL?
    /// Всего оплаченных уроков в текущем пакете (знаменатель индикатора "X/Y").
    public var paidLessonsTotal: Int
    /// Сколько оплаченных уроков уже использовано (числитель индикатора "X/Y").
    public var lessonsUsed: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#4E9CFF",
        pricePerLesson: Decimal = 0,
        workFormat: WorkFormat = .postpay,
        googleDocURL: URL? = nil,
        paidLessonsTotal: Int = 0,
        lessonsUsed: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.pricePerLesson = pricePerLesson
        self.workFormat = workFormat
        self.googleDocURL = googleDocURL
        self.paidLessonsTotal = max(0, paidLessonsTotal)
        self.lessonsUsed = max(0, lessonsUsed)
        self.createdAt = createdAt
    }

    /// Осталось оплаченных, но ещё не проведённых уроков.
    public var paidLessonsRemaining: Int {
        max(0, paidLessonsTotal - lessonsUsed)
    }

    /// Индикатор вида "1/4" (использовано/оплачено).
    public var paidLessonsIndicator: String {
        "\(lessonsUsed)/\(paidLessonsTotal)"
    }

    /// Абонемент на исходе: остался последний оплаченный урок или уже ни одного.
    /// При постоплате счётчик не ведётся, поэтому состояние не применяется.
    public var isPaidPackageEnding: Bool {
        workFormat == .subscription && paidLessonsRemaining <= 1
    }

    /// Короткая подпись подсветки: nil, если подсвечивать нечего.
    public var paidPackageEndingTitle: String? {
        guard isPaidPackageEnding else { return nil }
        return paidLessonsRemaining == 1 ? "Последний урок" : "Нет оплаченных"
    }
}
