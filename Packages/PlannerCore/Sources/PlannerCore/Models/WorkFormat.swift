import Foundation

/// Формат работы с учеником.
public enum WorkFormat: String, Codable, CaseIterable, Sendable, Hashable {
    /// Постоплата: ученик платит за каждый проведённый урок.
    case postpay
    /// Абонемент: ученик оплачивает пакет уроков заранее.
    case subscription

    /// Человекочитаемое название на русском.
    public var localizedTitle: String {
        switch self {
        case .postpay: return "Постоплата"
        case .subscription: return "Абонемент"
        }
    }
}
