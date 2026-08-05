import Foundation

/// Изменение, которое не удалось отправить на сервер.
///
/// Хранится локально и повторяется, когда связь появится. Без такой очереди
/// правка, сделанная без интернета, оставалась бы только на устройстве и
/// терялась навсегда.
public struct PendingOperation: Identifiable, Sendable, Equatable {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case upsertStudent
        case deleteStudent
        case upsertLesson
        case deleteLesson
        case upsertTask
        case deleteTask

        /// Ученики отправляются раньше уроков: урок ссылается на ученика внешним
        /// ключом, и обратный порядок приведёт к отказу на стороне PostgreSQL.
        var sendPriority: Int {
            switch self {
            case .upsertStudent: return 0
            case .upsertLesson, .upsertTask: return 1
            case .deleteLesson, .deleteTask: return 2
            case .deleteStudent: return 3
            }
        }
    }

    public let id: UUID
    /// Владелец изменения. Очередь одного аккаунта не должна отправляться от
    /// имени другого, поэтому операции всегда отбираются по этому полю.
    public let ownerId: UUID
    public let kind: Kind
    /// Идентификатор ученика, урока или задачи, которых касается операция.
    public let entityId: UUID
    /// JSON доменной модели для сохранения; для удаления — `nil`.
    public let payload: Data?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        ownerId: UUID,
        kind: Kind,
        entityId: UUID,
        payload: Data?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownerId = ownerId
        self.kind = kind
        self.entityId = entityId
        self.payload = payload
        self.createdAt = createdAt
    }
}

/// Хранилище очереди неотправленных изменений.
public protocol OutboxStore: Sendable {
    /// Поставить операцию в очередь. Прежние операции по той же сущности
    /// вытесняются: на сервер должно уехать итоговое состояние, а не вся
    /// история правок.
    func enqueue(_ operation: PendingOperation) async throws
    func pending(ownerId: UUID) async throws -> [PendingOperation]
    func remove(id: UUID) async throws
    func removeAll(ownerId: UUID) async throws
}

/// Очередь в памяти: демо-режим и UI-тесты не должны писать в базу устройства.
public actor InMemoryOutboxStore: OutboxStore {
    private var operations: [UUID: PendingOperation] = [:]

    public init() {}

    public func enqueue(_ operation: PendingOperation) async throws {
        for (key, existing) in operations
        where existing.ownerId == operation.ownerId && existing.entityId == operation.entityId {
            operations[key] = nil
        }
        operations[operation.id] = operation
    }

    public func pending(ownerId: UUID) async throws -> [PendingOperation] {
        operations.values
            .filter { $0.ownerId == ownerId }
            .sorted(by: PendingOperation.sendOrder)
    }

    public func remove(id: UUID) async throws {
        operations[id] = nil
    }

    public func removeAll(ownerId: UUID) async throws {
        for (key, existing) in operations where existing.ownerId == ownerId {
            operations[key] = nil
        }
    }
}

extension PendingOperation {
    /// Порядок отправки: сначала по зависимостям между сущностями, затем по
    /// времени появления в очереди.
    public static func sendOrder(_ lhs: PendingOperation, _ rhs: PendingOperation) -> Bool {
        if lhs.kind.sendPriority != rhs.kind.sendPriority {
            return lhs.kind.sendPriority < rhs.kind.sendPriority
        }
        return lhs.createdAt < rhs.createdAt
    }
}
