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

    /// Порог, при котором показываем полноценный разворот из двух страниц.
    private let spreadThreshold: CGFloat = 720

    var body: some View {
        let days = CalendarRange.weekDays(containing: env.selectedDate, calendar: env.calendar)
        GeometryReader { proxy in
            let isWide = proxy.size.width >= spreadThreshold
            ScrollView {
                VStack(spacing: 12) {
                    CalendarPeriodPlate(text: Formatters.monthYear.string(from: env.selectedDate).capitalized)
                    if isWide {
                        spread(days)
                    } else {
                        page(with: days, compact: true)
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

    // MARK: - Разворот / страница

    private func spread(_ days: [Date]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            page(with: Array(days.prefix(3)), compact: false)   // Пн, Вт, Ср
            spine
            page(with: Array(days.suffix(4)), compact: false)   // Чт, Пт, Сб, Вс
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

    private func page(with days: [Date], compact: Bool) -> some View {
        DiaryPage(
            days: days,
            compact: compact,
            onSelectDay: onSelectDay,
            onEditLesson: onEditLesson,
            onEditTask: onEditTask,
            onAdd: onAdd
        )
    }
}

// MARK: - Страница дневника

private struct DiaryPage: View {
    @EnvironmentObject private var env: AppEnvironment
    let days: [Date]
    let compact: Bool
    let onSelectDay: (Date) -> Void
    let onEditLesson: (Lesson) -> Void
    let onEditTask: (PersonalTask) -> Void
    let onAdd: (Date) -> Void

    private let labelWidth: CGFloat = 38
    private let minRowsPerDay = 4

    private var numWidth: CGFloat { compact ? 22 : 26 }
    private var timeWidth: CGFloat { compact ? 46 : 52 }
    private var statusWidth: CGFloat { compact ? 28 : 32 }
    /// Минимальная высота секции дня — чтобы вертикальная подпись дня умещалась.
    private var minSectionHeight: CGFloat { 132 }

    var body: some View {
        VStack(spacing: 0) {
            columnHeader
            ForEach(days, id: \.self) { day in
                daySection(day)
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

    // MARK: - Секция одного дня

    private func daySection(_ day: Date) -> some View {
        let entries = entries(on: day)
        let emptyCount = max(0, minRowsPerDay - entries.count)
        return HStack(alignment: .top, spacing: 6) {
            dayLabel(day)
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    entryRow(entry, number: index + 1)
                    Divider().overlay(DiaryTheme.line)
                }
                ForEach(0..<emptyCount, id: \.self) { offset in
                    emptyRow(day: day, showHint: entries.isEmpty && offset == 0)
                    Divider().overlay(DiaryTheme.line)
                }
            }
        }
        .frame(minHeight: minSectionHeight, alignment: .top)
        .padding(.bottom, 12)
    }

    private func dayLabel(_ day: Date) -> some View {
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
                // Вертикальная подпись дня недели, центрирована по высоте секции.
                Text(Formatters.weekdayFull.string(from: day).capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DiaryTheme.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                    .padding(.top, 14)
            }
            .frame(width: labelWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { onSelectDay(day) }
    }

    // MARK: - Строки

    @ViewBuilder
    private func entryRow(_ entry: DiaryEntry, number: Int) -> some View {
        switch entry {
        case .lesson(let lesson): lessonRow(lesson, number: number)
        case .task(let task): taskRow(task, number: number)
        }
    }

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
            name: nameCell(colorHex: colorHex, name: name, isTask: false, isDone: false, isEnding: isEnding),
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
        VStack(alignment: .leading, spacing: 3) {
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
        .padding(.vertical, 7)
        .padding(.horizontal, 2)
        // Подсветка лежит под слоем наведения, чтобы hover на macOS продолжал работать.
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(highlighted ? DiaryTheme.alert.opacity(0.10) : .clear)
        )
        .modifier(DiaryRowHover())
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private func nameCell(colorHex: String, name: String, isTask: Bool, isDone: Bool, isEnding: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 9, height: 9)
            Text(name)
                .font(.callout.weight(.medium))
                .foregroundStyle(DiaryTheme.ink)
                .strikethrough(isDone, color: DiaryTheme.inkSoft)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                // Метка держится вплотную к имени, поэтому колонку растягивает
                // не сам текст, а идущий следом отступ.
                .frame(maxWidth: isEnding ? nil : .infinity, alignment: .leading)
            if isEnding {
                LastLessonBadge()
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

    private func emptyRow(day: Date, showHint: Bool) -> some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: numWidth)
            if showHint {
                Label("Добавить запись", systemImage: "plus")
                    .font(.caption)
                    .foregroundStyle(DiaryTheme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .modifier(DiaryRowHover())
        .contentShape(Rectangle())
        .onTapGesture { onAdd(day) }
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
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func timeCell(_ date: Date) -> some View {
        Text(Formatters.time.string(from: date))
            .font(.caption.weight(.medium))
            .foregroundStyle(DiaryTheme.ink)
            .frame(width: timeWidth, alignment: .center)
    }

    // MARK: - Данные

    private func entries(on day: Date) -> [DiaryEntry] {
        let lessons = env.lessons(on: day).map(DiaryEntry.lesson)
        let tasks = env.tasks(on: day).map(DiaryEntry.task)
        return (lessons + tasks).sorted { $0.time < $1.time }
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
