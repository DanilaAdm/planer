import XCTest

/// UI-тесты запускаются в режиме `-uitest`: приложение использует хранилище
/// в памяти с одним предзаполненным учеником и уже «вошедшим» пользователем.
final class PlannerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitest", "-docReaderZoom", "1"]
        app.launch()
        return app
    }

    /// Элемент управления по названию или идентификатору. Один и тот же контрол
    /// SwiftUI на iOS и macOS имеет разный тип: вкладки и сегменты становятся
    /// radioButton, Picker — popUpButton, а его пункты — menuItem.
    private func control(_ name: String, in app: XCUIApplication) -> XCUIElement {
        let types = [
            XCUIElement.ElementType.button.rawValue,
            XCUIElement.ElementType.radioButton.rawValue,
            XCUIElement.ElementType.popUpButton.rawValue,
            XCUIElement.ElementType.menuItem.rawValue
        ]
        // Пункты меню на macOS отдают текст в `title`, кнопки — в `label`.
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@ AND (label == %@ OR identifier == %@ OR title == %@)",
                        types, name, name, name)
        ).firstMatch
    }

    private func tapControl(_ name: String, in app: XCUIApplication) {
        let element = control(name, in: app)
        XCTAssertTrue(element.waitForExistence(timeout: 15),
                      "Не найден элемент «\(name)»:\n\(app.debugDescription)")
        element.tap()
    }

    /// Переключатель: `switch` на iOS и `checkBox` на macOS.
    private func toggle(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let types = [
            XCUIElement.ElementType.switch.rawValue,
            XCUIElement.ElementType.checkBox.rawValue
        ]
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@ AND identifier == %@", types, identifier)
        ).firstMatch
    }

    /// Текст элемента: на iOS он в `label`, на macOS — в `value`.
    private func text(of element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }

    /// Фрагмент текста веб-страницы: WKWebView отдаёт его в `label` или в `value`.
    private func webText(_ fragment: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", fragment, fragment)
        ).firstMatch
    }

    func testTabsExist() {
        let app = launchApp()
        XCTAssertTrue(control("Календарь", in: app).waitForExistence(timeout: 15))
        XCTAssertTrue(control("Ученики", in: app).exists)
        XCTAssertTrue(control("Заработок", in: app).exists)
        XCTAssertTrue(control("Настройки", in: app).exists)
    }

    func testAddStudent() {
        let app = launchApp()
        tapControl("Ученики", in: app)

        app.buttons["addStudentButton"].tap()
        let nameField = app.textFields["studentNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Новый Ученик")
        app.buttons["saveStudentButton"].tap()

        XCTAssertTrue(app.staticTexts["Новый Ученик"].waitForExistence(timeout: 5))
    }

    func testStudentCardShowsPaidIndicator() {
        let app = launchApp()
        tapControl("Ученики", in: app)

        app.staticTexts["Тест Ученик"].tap()
        let indicator = app.staticTexts["paidIndicator"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 5))
        XCTAssertEqual(text(of: indicator), "1/4")
    }

    func testAddLessonAndMarkPaid() {
        let app = launchApp()
        tapControl("Календарь", in: app)

        app.buttons["addLessonButton"].tap()
        XCTAssertTrue(app.buttons["saveLessonButton"].waitForExistence(timeout: 5))

        // Выбрать ученика в пикере.
        tapControl("lessonStudentPicker", in: app)
        tapControl("Тест Ученик", in: app)

        toggle("lessonPaidSwitch", in: app).tap()
        app.buttons["saveLessonButton"].tap()

        XCTAssertTrue(app.buttons["addLessonButton"].waitForExistence(timeout: 5))
    }

    func testCalendarModeNavigation() {
        let app = launchApp()
        tapControl("Календарь", in: app)

        XCTAssertTrue(control("Месяц", in: app).waitForExistence(timeout: 5))
        tapControl("Месяц", in: app)
        tapControl("День", in: app)
        tapControl("Неделя", in: app)
    }

    /// Главная проверка Google-документа: в профиле Ксюши он открывается
    /// внутри приложения и в нём видно содержимое документа.
    func testKsyushaDocumentOpens() throws {
        let app = launchApp()
        tapControl("Ученики", in: app)

        XCTAssertTrue(app.staticTexts["Ксюша"].waitForExistence(timeout: 10))
        app.staticTexts["Ксюша"].tap()

        let openDoc = app.buttons["openDocButton"]
        XCTAssertTrue(openDoc.waitForExistence(timeout: 5), "В карточке Ксюши нет кнопки открытия документа")
        openDoc.tap()

        let closeButton = app.buttons["docCloseButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 15),
                      "Просмотрщик документа не появился:\n\(app.debugDescription)")

        // Ждём, что появится либо текст из документа, либо сообщение об ошибке загрузки.
        let title = webText("Ксюша - русский язык", in: app)
        let accessibleContent = app.webViews.matching(identifier: "docWebView").matching(
            NSPredicate(format: "value CONTAINS %@", "Ксюша - русский язык")
        ).firstMatch
        let error = app.descendants(matching: .any)["docErrorMessage"]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                title.exists || accessibleContent.exists || error.exists
            },
            object: nil
        )
        _ = XCTWaiter().wait(for: [ready], timeout: 45)

        if error.exists {
            // Без сети (например, на машине с VPN) проверять нечего — это не дефект приложения.
            let message = text(of: error)
            if message.contains("Нет связи с интернетом") {
                throw XCTSkip("Нет доступа к сети: \(message)")
            }
            XCTFail("Документ не загрузился: \(message)")
        }
        XCTAssertTrue(title.exists || accessibleContent.exists,
                      "В документе не появился заголовок «Ксюша - русский язык»:\n\(app.debugDescription)")

        // WebKit сообщает о готовом DOM раньше первого визуального кадра.
        // Даём WKWebView закончить отрисовку перед снимком.
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "render")], timeout: 2)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Документ Ксюши"
        shot.lifetime = .keepAlways
        add(shot)

        // Раздел «РУССКИЙ ЯЗЫК» лежит ниже: на iOS в дерево доступности попадает
        // только отрисованная часть страницы, поэтому прокручиваем до него.
        let heading = webText("РУССКИЙ ЯЗЫК", in: app)
        let accessibleHeading = app.webViews.matching(identifier: "docWebView").matching(
            NSPredicate(format: "value CONTAINS %@", "РУССКИЙ ЯЗЫК")
        ).firstMatch
        for _ in 0..<20 where !heading.exists && !accessibleHeading.exists {
            app.windows.firstMatch.swipeUp()
        }
        XCTAssertTrue(heading.exists || accessibleHeading.exists,
                      "В документе не найден раздел «РУССКИЙ ЯЗЫК»")

        // Крупнее / закрыть — управление просмотрщиком.
        let zoomIn = app.buttons["docZoomInButton"]
        if zoomIn.exists { zoomIn.tap() }

        closeButton.tap()
        XCTAssertTrue(openDoc.waitForExistence(timeout: 5), "Просмотрщик не закрылся обратно в карточку")
    }

    /// Блок урока занимает ровно свой интервал: верх — по метке часа начала,
    /// высота — пропорционально длительности, без наезда на соседние слоты.
    func testDayLessonBlocksFitTheirTimeSlots() {
        let app = launchApp()
        tapControl("Календарь", in: app)
        tapControl("День", in: app)

        let hourStart = app.staticTexts["hourLabel-9"]
        XCTAssertTrue(hourStart.waitForExistence(timeout: 15),
                      "Дневная сетка не появилась:\n\(app.debugDescription)")
        // Высота часа берётся из самой сетки, чтобы тест не зависел от вёрстки платформы.
        let hourHeight = app.staticTexts["hourLabel-10"].frame.minY - hourStart.frame.minY
        XCTAssertGreaterThan(hourHeight, 0, "Не удалось измерить высоту часа")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "День — блоки уроков"
        shot.lifetime = .keepAlways
        add(shot)

        // Короткий, ровно часовой и длинный урок из предзаполненных данных.
        for (hour, minutes) in [(9, 30), (11, 60), (14, 90)] {
            let block = app.descendants(matching: .any)["lessonBlock-\(hour)"]
            XCTAssertTrue(block.waitForExistence(timeout: 5),
                          "Не найден блок урока на \(hour):00")

            let slotTop = app.staticTexts["hourLabel-\(hour)"].frame.minY
            let expectedHeight = hourHeight * CGFloat(minutes) / 60
            // Допуск на скругление координат в дереве доступности.
            let tolerance: CGFloat = 1.5

            XCTAssertEqual(block.frame.minY, slotTop, accuracy: tolerance,
                           "Верх блока не совпадает с началом \(hour):00")
            XCTAssertEqual(block.frame.height, expectedHeight, accuracy: tolerance,
                           "Высота блока не соответствует \(minutes) минутам")
            XCTAssertEqual(block.frame.maxY, slotTop + expectedHeight, accuracy: tolerance,
                           "Низ блока выходит за конец урока на \(hour):00")
        }
    }

    func testEarningsScreenShowsTotal() {
        let app = launchApp()
        tapControl("Заработок", in: app)
        XCTAssertTrue(app.staticTexts["totalEarnings"].waitForExistence(timeout: 5))
    }
}
