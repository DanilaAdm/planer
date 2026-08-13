import SwiftUI
import PlannerCore

/// Оформление в стиле бумажного дневника.
///
/// Значения совпадают с общими токенами дизайн-системы (`Theme`), чтобы
/// недельный дневник оставался эталоном стиля для остальных экранов.
private enum DiaryTheme {
    static let paper = Color(hex: "#E9EAF2")
    static let page = Theme.surface
    static let ink = Theme.ink
    static let line = Color(hex: "#33417E").opacity(0.22)
    static let accent = Theme.outline
    /// Подсветка ученика, у которого заканчивается абонемент.
    static let alert = Theme.attention

    /// Чуть повышенный контраст вторичных подписей для лучшей читаемости.
    static var inkSoft: Color { ink.opacity(0.6) }
}

/// Одна запись дневника: урок (Работа) или личная задача (Планы).
private enum DiaryEntry: Identifiable {
    case lesson(Lesson)
    case task(PersonalTask)

    var id: UUID {
        switch self {
        case .lesson(let l): return l.id
        case .task(let t): return t.id
        }
    }

    var time: Date {
        switch self {
        case .lesson(let l): return l.startAt
        case .task(let t): return t.scheduledAt
        }
    }
}

/// Блок разворота: день недели или заметки недели.
private struct DiaryBlock: Identifiable {
    enum Kind: Equatable {
        case day(Date)
        case notes
    }

    let kind: Kind
    /// Сколько строк-слотов отведено блоку (см. `DiaryLayout`).
    let rows: Int

    var id: String {
        switch kind {
        case .day(let day): return "day-\(day.timeIntervalSince1970)"
        case .notes: return "notes"
        }
    }

    var accessibilityIdentifier: String {
        switch kind {
        case .day(let day): return "diaryDaySection-\(Formatters.dayKey.string(from: day))"
        case .notes: return "diaryNotesSection"
        }
    }
}

/// Строка блока: занятый слот или свободный.
private enum DiarySlot: Identifiable {
    case entry(DiaryEntry, number: Int)
    case note(WeekNote, number: Int)
    /// Свободный слот. `hint` — единственная подсказка «добавить» в пустом блоке.
    case empty(index: Int, hint: Bool)

    var id: String {
        switch self {
        case .entry(let entry, _): return "entry-\(entry.id)"
        case .note(let note, _): return "note-\(note.id)"
        case .empty(let index, _): return "empty-\(index)"
        }
    }
}

/// Записи дня: уроки и личные задачи, упорядоченные по времени.
@MainActor
private func diaryEntries(on day: Date, env: AppEnvironment) -> [DiaryEntry] {
    let lessons = env.lessons(on: day).map(DiaryEntry.lesson)
    let tasks = env.tasks(on: day).map(DiaryEntry.task)
    return (lessons + tasks).sorted { $0.time < $1.time }
}

/// Планер недели в виде разворота школьного дневника.
///
/// На широком экране (desktop / iPad-альбом) — двухстраничный разворот с колонками,
/// на узком (iPhone) — одна страница, где заметка переносится на вторую строку,
/// чтобы имена и задачи всегда были читаемы.
struct DiaryWeekView: View {
    @EnvironmentObject private var env: AppEnvironment
    let onSelectDay: (Date) -> Void
    let onEditLesson: (Lesson) -> Void
    let onEditTask: (PersonalTask) -> Void
    let onAdd: (Date) -> Void
    let onEditNote: (WeekNote) -> Void
    let onAddNote: () -> Void

    /// Порог, при котором показываем полноценный разворот из двух страниц.
    private let spreadThreshold: CGFloat = 720

    var body: some View {
        let days = CalendarRange.weekDays(containing: env.selectedDate, calendar: env.calendar)
        GeometryReader { proxy in
            let isWide = proxy.size.width >= spreadThreshold
            let blocks = blocks(for: days, paired: isWide)
            ScrollView {
                VStack(spacing: 12) {
                    CalendarPeriodPlate(text: Formatters.monthYear.string(from: env.selectedDate).capitalized)
                    if isWide {
                        spread(blocks)
                    } else {
                        page(with: blocks, compact: true)
                            .frame(maxWidth: 620)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, isWide ? 20 : 10)
                .padding(.vertical, 12)
            }
            .background(DiaryTheme.paper.ignoresSafeArea())
        }
        .task { await env.loadLessons(for: env.selectedDate, scope: .week) }
    }

    // MARK: - Разметка блоков

    /// Блоки недели с уже посчитанным числом слотов.
    ///
    /// Считается один раз для всего разворота: только так блоки, стоящие друг
    /// напротив друга, получают одинаковую высоту и растут вместе.
    private func blocks(for days: [Date], paired: Bool) -> [DiaryBlock] {
        let counts = DiaryLayout.rowCounts(
            dayEntryCounts: days.map { diaryEntries(on: $0, env: env).count },
            noteCount: env.notes(forWeekOf: env.selectedDate).count,
            paired: paired
        )
        var result = zip(days, counts.days).map { DiaryBlock(kind: .day($0), rows: $1) }
        result.append(DiaryBlock(kind: .notes, rows: counts.notes))
        return result
    }

    // MARK: - Разворот / страница

    /// Левая страница — Пн, Вт, Ср и блок заметок; правая — Чт, Пт, Сб, Вс.
    /// Блок заметок стоит напротив воскресенья, поэтому страницы равной высоты.
    private func spread(_ blocks: [DiaryBlock]) -> some View {
        let dayBlocks = blocks.filter { $0.kind != .notes }
        let notesBlock = blocks.filter { $0.kind == .notes }
        let left = Array(dayBlocks.prefix(DiaryLayout.leftPageDayCount)) + notesBlock
        let right = Array(dayBlocks.dropFirst(DiaryLayout.leftPageDayCount))
        return HStack(alignment: .top, spacing: 0) {
            page(with: left, compact: false)
            spine
            page(with: right, compact: false)
        }
    }

    private var spine: some View {
        LinearGradient(
            colors: [DiaryTheme.ink.opacity(0.02), DiaryTheme.ink.opacity(0.16), DiaryTheme.ink.opacity(0.02)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 14)
    }

    private func page(with blocks: [DiaryBlock], compact: Bool) -> some View {
        DiaryPage(
            blocks: blocks,
            compact: compact,
            onSelectDay: onSelectDay,
            onEditLesson: onEditLesson,
            onEditTask: onEditTask,
            onAdd: onAdd,
            onEditNote: onEditNote,
            onAddNote: onAddNote
        )
    }
}

// MARK: - Страница дневника

private struct DiaryPage: View {
    @EnvironmentObject private var env: AppEnvironment
    let blocks: [DiaryBlock]
    let compact: Bool
    let onSelectDay: (Date) -> Void
    let onEditLesson: (Lesson) -> Void
    let onEditTask: (PersonalTask) -> Void
    let onAdd: (Date) -> Void
    let onEditNote: (WeekNote) -> Void
    let onAddNote: () -> Void

    private let labelWidth: CGFloat = 38
    private let blockSpacing: CGFloat = 12

    private var numWidth: CGFloat { compact ? 22 : 26 }
    private var timeWidth: CGFloat { compact ? 46 : 52 }
    private var statusWidth: CGFloat { compact ? 28 : 32 }
    /// Высота одного слота.
    ///
    /// Фиксированная намеренно: высота блока считается как «слоты × высота
    /// строки», поэтому одинаковое число слотов даёт одинаковую высоту на обеих
    /// страницах разворота. Если бы строка росла под текст, границы дней слева и
    /// справа снова разъехались бы, а записи наехали на соседний день.
    private var rowHeight: CGFloat { compact ? 46 : 34 }

    var body: some View {
        VStack(spacing: 0) {
            columnHeader
            ForEach(blocks) { block in
                blockView(block)
                    .padding(.bottom, blockSpacing)
            }
        }
        .padding(compact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DiaryTheme.page)
                .shadow(color: DiaryTheme.ink.opacity(0.12), radius: 10, x: 0, y: 4)
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Заголовок колонок

    private var columnHeader: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: labelWidth, height: 14)
            headerCell("№", width: numWidth)
            headerCell("Ученик / задача")
            if !compact {
                headerCell("Информация")
            }
            headerCell("Время", width: timeWidth)
            headerCell("✓", width: statusWidth)
        }
        // Фиксируем высоту шапки, чтобы она была одинаковой на обеих страницах
        // разворота и не растягивалась при заполнении дневника.
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: 20)
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DiaryTheme.accent, lineWidth: 1.2)
        )
        .padding(.bottom, 6)
    }

    private func headerCell(_ title: String, width: CGFloat? = nil) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(DiaryTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: width, alignment: width == nil ? .leading : .center)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    // MARK: - Блок дня или заметок

    @ViewBuilder
    private func blockView(_ block: DiaryBlock) -> some View {
        let height = rowHeight * CGFloat(block.rows)
        HStack(alignment: .top, spacing: 6) {
            switch block.kind {
            case .day(let day): dayLabel(day, height: height)
            case .notes: notesLabel(height: height)
            }
            VStack(spacing: 0) {
                ForEach(slots(for: block)) { slot in
                    slotRow(slot, in: block)
                }
            }
        }
        .frame(height: height, alignment: .top)
        .accessibilityIdentifier(block.accessibilityIdentifier)
    }

    /// Слоты блока: сначала занятые строки, затем свободные до нужного числа.
    private func slots(for block: DiaryBlock) -> [DiarySlot] {
        var filled: [DiarySlot] = []
        switch block.kind {
        case .day(let day):
            filled = diaryEntries(on: day, env: env).enumerated().map { index, entry in
                .entry(entry, number: index + 1)
            }
        case .notes:
            filled = env.notes(forWeekOf: env.selectedDate).enumerated().map { index, note in
                .note(note, number: index + 1)
            }
        }
        guard filled.count < block.rows else { return filled }
        let empties: [DiarySlot] = (filled.count..<block.rows).map { index in
            .empty(index: index, hint: filled.isEmpty && index == 0)
        }
        return filled + empties
    }

    @ViewBuilder
    private func slotRow(_ slot: DiarySlot, in block: DiaryBlock) -> some View {
        switch slot {
        case .entry(let entry, let number):
            switch entry {
            case .lesson(let lesson): lessonRow(lesson, number: number)
            case .task(let task): taskRow(task, number: number)
            }
        case .note(let note, let number):
            noteRow(note, number: number)
        case .empty(_, let hint):
            emptyRow(block: block, showHint: hint)
        }
    }

    private func dayLabel(_ day: Date, height: CGFloat) -> some View {
        let isToday = env.calendar.isDateInToday(day)
        return RoundedRectangle(cornerRadius: 10)
            .fill(isToday ? DiaryTheme.accent.opacity(0.16) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DiaryTheme.accent, lineWidth: 1.2))
            .overlay(alignment: .top) {
                Text(Formatters.dayNumber.string(from: day))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(DiaryTheme.ink)
                    .padding(.top, 7)
            }
            .overlay {
                // Вертикальная подпись дня недели, центрирована по высоте блока.
                Text(Formatters.weekdayFull.string(from: day).capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DiaryTheme.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    .padding(.top, 14)
            }
            .frame(width: labelWidth, height: height)
            .contentShape(Rectangle())
            .onTapGesture { onSelectDay(day) }
    }

    /// Подпись блока заметок: стоит напротив воскресенья и держит ту же колонку,
    /// что и подписи дней, иначе разлиновка страниц разъехалась бы.
    private func notesLabel(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DiaryTheme.accent, lineWidth: 1.2))
            .overlay {
                Text("Заметки")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DiaryTheme.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: labelWidth, height: height)
    }

    // MARK: - Строки

    private func lessonRow(_ lesson: Lesson, number: Int) -> some View {
        let student = env.student(for: lesson.studentId)
        let colorHex = student?.colorHex ?? HexColor.palette[0]
        let name = student?.name ?? "Урок"
        let info = lesson.note ?? "Занятие"
        let isEnding = student?.isPaidPackageEnding ?? false
        let status = Button {
            Task { await env.toggleLessonPaid(lesson) }
        } label: {
            Image(systemName: lesson.isPaid ? "checkmark.seal.fill" : "seal")
                .foregroundStyle(lesson.isPaid ? Theme.success : DiaryTheme.inkSoft)
        }
        .buttonStyle(.plain)
        .frame(width: statusWidth)
        .accessibilityIdentifier("diaryLessonPaidToggle")

        return row(
            number: number,
            name: nameCell(colorHex: colorHex, name: name, isTask: false, isDone: false,
                           isEnding: isEnding, repeatsWeekly: lesson.repeatsWeekly),
            info: info,
            time: lesson.startAt,
            status: status,
            highlighted: isEnding,
            onTap: { onEditLesson(lesson) }
        )
    }

    private func taskRow(_ task: PersonalTask, number: Int) -> some View {
        let status = Button {
            Task { await env.toggleTaskDone(task) }
        } label: {
            Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                .foregroundStyle(task.isDone ? Theme.success : DiaryTheme.inkSoft)
        }
        .buttonStyle(.plain)
        .frame(width: statusWidth)
        .accessibilityIdentifier("diaryTaskDoneToggle")

        return row(
            number: number,
            name: nameCell(colorHex: task.colorHex, name: task.title, isTask: true, isDone: task.isDone, isEnding: false),
            info: task.note ?? "Личная задача",
            time: task.scheduledAt,
            status: status,
            highlighted: false,
            onTap: { onEditTask(task) }
        )
    }

    /// Строка заметки недели: времени и отметки у неё нет, но колонки те же —
    /// разлиновка блока совпадает с блоками дней.
    private func noteRow(_ note: WeekNote, number: Int) -> some View {
        slot(highlighted: false, onTap: { onEditNote(note) }) {
            HStack(alignment: .center, spacing: 6) {
                numberCell(number)
                Text(note.text)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DiaryTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: timeWidth, height: 0)
                Color.clear.frame(width: statusWidth, height: 0)
            }
        }
        .accessibilityIdentifier("diaryNoteRow")
    }

    /// Универсальная строка. В compact-режиме заметка переносится на вторую строку.
    private func row<Name: View, Status: View>(
        number: Int,
        name: Name,
        info: String,
        time: Date,
        status: Status,
        highlighted: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        slot(highlighted: highlighted, onTap: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 6) {
                    numberCell(number)
                    name
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !compact {
                        infoText(info)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    timeCell(time)
                    status
                }
                if compact && !info.isEmpty {
                    HStack(spacing: 6) {
                        Color.clear.frame(width: numWidth, height: 0)
                        infoText(info)
                    }
                }
            }
        }
    }

    /// Оформление слота: фиксированная высота, разлиновка снизу и реакция на тап.
    private func slot<Content: View>(
        highlighted: Bool,
        onTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 2)
            .frame(height: rowHeight)
            // Подсветка лежит под слоем наведения, чтобы hover на macOS продолжал работать.
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(highlighted ? DiaryTheme.alert.opacity(0.10) : .clear)
            )
            .modifier(DiaryRowHover())
            // Линия-разлиновка рисуется внутри слота: иначе она добавляла бы
            // высоту, и блок перестал быть кратным высоте строки.
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DiaryTheme.line)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }

    private func nameCell(
        colorHex: String,
        name: String,
        isTask: Bool,
        isDone: Bool,
        isEnding: Bool,
        repeatsWeekly: Bool = false
    ) -> some View {
        // Метки держатся вплотную к имени, поэтому колонку растягивает не сам
        // текст, а идущий за ними отступ.
        let hasMark = isEnding || repeatsWeekly
        return HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 9, height: 9)
            // Имя держится в одну строку: перенос сделал бы строки разной высоты
            // и развалил бы совпадение блоков на развороте. Целиком имя и заметка
            // видны в редакторе записи — по тапу на строку.
            Text(name)
                .font(.callout.weight(.medium))
                .foregroundStyle(DiaryTheme.ink)
                .strikethrough(isDone, color: DiaryTheme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .frame(maxWidth: hasMark ? nil : .infinity, alignment: .leading)
            if isEnding {
                LastLessonBadge()
            }
            if repeatsWeekly {
                WeeklyRepeatMark()
            }
            if hasMark {
                Spacer(minLength: 0)
            }
            if isTask {
                Text("Планы")
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(Color(hex: colorHex))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(hex: colorHex).opacity(0.15)))
            }
        }
    }

    /// Свободный слот. Он есть в каждом блоке всегда: как только заполнен
    /// последний, появляется следующий — и в парном блоке напротив тоже.
    private func emptyRow(block: DiaryBlock, showHint: Bool) -> some View {
        let isNotes = block.kind == .notes
        return slot(highlighted: false, onTap: {
            switch block.kind {
            case .day(let day): onAdd(day)
            case .notes: onAddNote()
            }
        }) {
            HStack(spacing: 6) {
                Color.clear.frame(width: numWidth)
                if showHint {
                    Label(isNotes ? "Добавить заметку" : "Добавить запись", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(DiaryTheme.inkSoft)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier(isNotes ? "diaryNoteEmptyRow" : "diaryEmptyRow")
    }

    // MARK: - Ячейки

    private func numberCell(_ number: Int) -> some View {
        Text("\(number)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(DiaryTheme.inkSoft)
            .frame(width: numWidth, alignment: .center)
    }

    private func infoText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(DiaryTheme.inkSoft)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private func timeCell(_ date: Date) -> some View {
        Text(Formatters.time.string(from: date))
            .font(.caption.weight(.medium))
            .foregroundStyle(DiaryTheme.ink)
            .frame(width: timeWidth, alignment: .center)
    }
}

// MARK: - Подсветка строки при наведении (macOS)

/// Мягкая подсветка строки дневника под курсором. На iOS ничего не меняет.
private struct DiaryRowHover: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DiaryTheme.accent.opacity(hovering ? 0.10 : 0))
            )
            #if os(macOS)
            .onHover { hovering = $0 }
            #endif
    }
}
