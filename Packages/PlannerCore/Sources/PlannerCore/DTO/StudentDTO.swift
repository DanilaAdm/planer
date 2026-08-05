import Foundation

/// DTO ученика для обмена с PostgreSQL (snake_case, как в таблице `students`).
public struct StudentDTO: Codable, Sendable, Equatable {
    public var id: UUID
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
        self.name = name
        self.color_hex = color_hex
        self.price_per_lesson = price_per_lesson
        self.work_format = work_format
        self.google_doc_url = google_doc_url
        self.paid_lessons_total = paid_lessons_total
        self.lessons_used = lessons_used
        self.created_at = created_at
    }

    public init(_ student: Student) {
        self.init(
            id: student.id,
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
