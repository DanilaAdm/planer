import XCTest
@testable import PlannerCore

final class DTOMappingTests: XCTestCase {
    func testStudentRoundTrip() {
        let student = Student(
            name: "Мария",
            colorHex: "#3DD598",
            pricePerLesson: 1500,
            workFormat: .subscription,
            googleDocURL: URL(string: "https://docs.google.com/document/d/abc"),
            paidLessonsTotal: 4,
            lessonsUsed: 1
        )
        let dto = StudentDTO(student)
        let restored = dto.toDomain()
        XCTAssertEqual(restored.id, student.id)
        XCTAssertEqual(restored.name, student.name)
        XCTAssertEqual(restored.colorHex, student.colorHex)
        XCTAssertEqual(restored.pricePerLesson, student.pricePerLesson)
        XCTAssertEqual(restored.workFormat, student.workFormat)
        XCTAssertEqual(restored.googleDocURL, student.googleDocURL)
        XCTAssertEqual(restored.paidLessonsTotal, student.paidLessonsTotal)
        XCTAssertEqual(restored.lessonsUsed, student.lessonsUsed)
    }

    func testStudentDTOCodableUsesSnakeCaseKeys() throws {
        let student = TestSupport.makeStudent(name: "Пётр", format: .postpay)
        let data = try PlannerCoding.makeEncoder().encode(StudentDTO(student))
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"color_hex\""))
        XCTAssertTrue(json.contains("\"price_per_lesson\""))
        XCTAssertTrue(json.contains("\"work_format\""))
        XCTAssertTrue(json.contains("\"paid_lessons_total\""))
    }

    func testUnknownWorkFormatDefaultsToPostpay() {
        let dto = StudentDTO(
            id: UUID(), name: "X", color_hex: "#FFFFFF", price_per_lesson: 0,
            work_format: "weird", google_doc_url: nil,
            paid_lessons_total: 0, lessons_used: 0, created_at: Date()
        )
        XCTAssertEqual(dto.toDomain().workFormat, .postpay)
    }

    func testLessonRoundTrip() {
        let lesson = Lesson(
            studentId: UUID(),
            startAt: TestSupport.date(2026, 3, 2, 10),
            durationMinutes: 90,
            isPaid: true,
            note: "Алгебра"
        )
        let dto = LessonDTO(lesson)
        let restored = dto.toDomain()
        XCTAssertEqual(restored.id, lesson.id)
        XCTAssertEqual(restored.studentId, lesson.studentId)
        XCTAssertEqual(restored.startAt, lesson.startAt)
        XCTAssertEqual(restored.durationMinutes, lesson.durationMinutes)
        XCTAssertEqual(restored.isPaid, lesson.isPaid)
        XCTAssertEqual(restored.note, lesson.note)
    }

    func testLessonDTOEncodeDecodeWithDates() throws {
        let lesson = Lesson(studentId: UUID(), startAt: TestSupport.date(2026, 3, 2, 10, 30), durationMinutes: 60)
        let encoder = PlannerCoding.makeEncoder()
        let decoder = PlannerCoding.makeDecoder()
        let data = try encoder.encode(LessonDTO(lesson))
        let decoded = try decoder.decode(LessonDTO.self, from: data)
        XCTAssertEqual(decoded.start_at.timeIntervalSince1970,
                       lesson.startAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func testPersonalTaskRoundTrip() {
        let task = PersonalTask(
            title: "Подготовить материалы",
            scheduledAt: TestSupport.date(2026, 3, 2, 12),
            note: "Распечатать карточки",
            isDone: true,
            colorHex: "#8A94B8"
        )
        let dto = PersonalTaskDTO(task)
        let restored = dto.toDomain()
        XCTAssertEqual(restored.id, task.id)
        XCTAssertEqual(restored.title, task.title)
        XCTAssertEqual(restored.scheduledAt, task.scheduledAt)
        XCTAssertEqual(restored.note, task.note)
        XCTAssertEqual(restored.isDone, task.isDone)
        XCTAssertEqual(restored.colorHex, task.colorHex)
    }

    func testPersonalTaskDTOUsesSnakeCaseKeys() throws {
        let task = PersonalTask(title: "Дело", scheduledAt: TestSupport.date(2026, 3, 2, 9))
        let data = try PlannerCoding.makeEncoder().encode(PersonalTaskDTO(task))
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"scheduled_at\""))
        XCTAssertTrue(json.contains("\"is_done\""))
        XCTAssertTrue(json.contains("\"color_hex\""))
    }

    // MARK: - Очистка полей и владелец

    /// Пустое значение обязано уехать как `null`: иначе PostgREST не увидит поле
    /// в теле запроса и оставит в базе прежнюю ссылку.
    func testClearedGoogleDocURLIsSentAsNull() throws {
        var student = TestSupport.makeStudent(name: "Без документа")
        student.googleDocURL = nil
        let json = try encodedJSON(StudentDTO(student))
        XCTAssertTrue(json.contains("\"google_doc_url\":null"), "Получено: \(json)")
    }

    func testClearedLessonNoteIsSentAsNull() throws {
        let lesson = Lesson(studentId: UUID(), startAt: TestSupport.date(2026, 3, 2, 10), note: nil)
        let json = try encodedJSON(LessonDTO(lesson))
        XCTAssertTrue(json.contains("\"note\":null"), "Получено: \(json)")
    }

    func testClearedTaskNoteIsSentAsNull() throws {
        let task = PersonalTask(title: "Дело", scheduledAt: TestSupport.date(2026, 3, 2, 9), note: nil)
        let json = try encodedJSON(PersonalTaskDTO(task))
        XCTAssertTrue(json.contains("\"note\":null"), "Получено: \(json)")
    }

    /// Дату создания проставляет сервер: отправляя её, клиент перезаписывал бы
    /// значение в базе при каждом сохранении.
    func testCreatedAtIsNotSentToServer() throws {
        let student = TestSupport.makeStudent(name: "Кто-то")
        XCTAssertFalse(try encodedJSON(StudentDTO(student)).contains("created_at"))

        let lesson = Lesson(studentId: UUID(), startAt: TestSupport.date(2026, 3, 2, 10))
        XCTAssertFalse(try encodedJSON(LessonDTO(lesson)).contains("created_at"))

        let task = PersonalTask(title: "Дело", scheduledAt: TestSupport.date(2026, 3, 2, 9))
        XCTAssertFalse(try encodedJSON(PersonalTaskDTO(task)).contains("created_at"))
    }

    func testOwnerIdIsSentWhenKnownAndOmittedOtherwise() throws {
        let owner = UUID()
        let student = TestSupport.makeStudent(name: "Владелец")
        XCTAssertTrue(try encodedJSON(StudentDTO(student, ownerId: owner)).contains("owner_id"))
        XCTAssertFalse(try encodedJSON(StudentDTO(student)).contains("owner_id"))
    }

    /// Ответ сервера содержит `created_at` и `owner_id` — декодирование обязано
    /// их принимать, хотя обратно они не отправляются.
    func testDecodesServerPayloadWithOwnerAndCreatedAt() throws {
        let json = """
            {"id":"\(UUID().uuidString)","owner_id":"\(UUID().uuidString)","name":"Аня",
             "color_hex":"#4E9CFF","price_per_lesson":1200,"work_format":"postpay",
             "google_doc_url":null,"paid_lessons_total":0,"lessons_used":0,
             "created_at":"2026-03-02T10:00:00.000Z"}
            """
        let dto = try PlannerCoding.makeDecoder().decode(StudentDTO.self, from: Data(json.utf8))
        XCTAssertEqual(dto.name, "Аня")
        XCTAssertNil(dto.google_doc_url)
        XCTAssertNotNil(dto.owner_id)
    }

    private func encodedJSON<T: Encodable>(_ value: T) throws -> String {
        String(data: try PlannerCoding.makeEncoder().encode(value), encoding: .utf8)!
    }
}
