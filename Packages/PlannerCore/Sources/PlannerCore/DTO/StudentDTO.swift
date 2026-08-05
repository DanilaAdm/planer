import Foundation

/// DTO ученика для обмена с PostgreSQL (snake_case, как в таблице `students`).
public struct StudentDTO: Codable, Sendable, Equatable {
    public var id: UUID
    /// Владелец записи. Сервер всё равно перезапишет поле значением из токена,
    /// но отправлять его явно надёжнее, чем полагаться на умолчание в схеме.
    public var owner_id: UUID?
    public var name: String
    public var color_hex: String
    public var price_per_lesson: Decimal
    public var work_format: String
    public var google_doc_url: String?
    public var paid_lessons_total: Int
    public var lessons_used: Int
    public var created_at: Date

    public init(
        id: UUID,
        owner_id: UUID? = nil,
        name: String,
        color_hex: String,
        price_per_lesson: Decimal,
        work_format: String,
        google_doc_url: String?,
        paid_lessons_total: Int,
        lessons_used: Int,
        created_at: Date
    ) {
        self.id = id
        self.owner_id = owner_id
        self.name = name
        self.color_hex = color_hex
        self.price_per_lesson = price_per_lesson
        self.work_format = work_format
        self.google_doc_url = google_doc_url
        self.paid_lessons_total = paid_lessons_total
        self.lessons_used = lessons_used
        self.created_at = created_at
    }

    public init(_ student: Student, ownerId: UUID? = nil) {
        self.init(
            id: student.id,
            owner_id: ownerId,
            name: student.name,
            color_hex: student.colorHex,
            price_per_lesson: student.pricePerLesson,
            work_format: student.workFormat.rawValue,
            google_doc_url: student.googleDocURL?.absoluteString,
            paid_lessons_total: student.paidLessonsTotal,
            lessons_used: student.lessonsUsed,
            created_at: student.createdAt
        )
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, owner_id, name, color_hex, price_per_lesson
        case work_format, google_doc_url, paid_lessons_total, lessons_used, created_at
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        owner_id = try container.decodeIfPresent(UUID.self, forKey: .owner_id)
        name = try container.decode(String.self, forKey: .name)
        color_hex = try container.decode(String.self, forKey: .color_hex)
        price_per_lesson = try container.decode(Decimal.self, forKey: .price_per_lesson)
        work_format = try container.decode(String.self, forKey: .work_format)
        google_doc_url = try container.decodeIfPresent(String.self, forKey: .google_doc_url)
        paid_lessons_total = try container.decode(Int.self, forKey: .paid_lessons_total)
        lessons_used = try container.decode(Int.self, forKey: .lessons_used)
        // Дату создания проставляет сервер, поэтому в теле запроса её нет.
        created_at = try container.decodeIfPresent(Date.self, forKey: .created_at) ?? Date()
    }

    /// Кодируется вручную по двум причинам.
    ///
    /// Во-первых, `google_doc_url` должен уезжать как `null`, когда ссылку
    /// удалили: синтезированный `Codable` пропускает пустые значения, и старая
    /// ссылка оставалась бы в базе. Во-вторых, `created_at` не отправляется —
    /// иначе повторное сохранение перезаписывало бы дату создания на сервере.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(owner_id, forKey: .owner_id)
        try container.encode(name, forKey: .name)
        try container.encode(color_hex, forKey: .color_hex)
        try container.encode(price_per_lesson, forKey: .price_per_lesson)
        try container.encode(work_format, forKey: .work_format)
        try container.encode(google_doc_url, forKey: .google_doc_url)
        try container.encode(paid_lessons_total, forKey: .paid_lessons_total)
        try container.encode(lessons_used, forKey: .lessons_used)
    }

    public func toDomain() -> Student {
        Student(
            id: id,
            name: name,
            colorHex: HexColor.normalized(color_hex),
            pricePerLesson: price_per_lesson,
            workFormat: WorkFormat(rawValue: work_format) ?? .postpay,
            googleDocURL: google_doc_url.flatMap(URL.init(string:)),
            paidLessonsTotal: paid_lessons_total,
            lessonsUsed: lessons_used,
            createdAt: created_at
        )
    }
}
