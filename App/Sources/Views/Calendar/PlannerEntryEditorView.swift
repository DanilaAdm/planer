import SwiftUI
import PlannerCore

/// Тип записи в планере: работа с учеником или личная задача.
enum EntryKind: String, CaseIterable, Identifiable {
    case work = "Работа"
    case plans = "Планы"
    var id: String { rawValue }
}

/// Универсальная форма создания/редактирования записи планера.
///
/// При создании новой записи доступен выбор «Работа/Планы». При редактировании
/// существующего урока или задачи тип зафиксирован.
struct PlannerEntryEditorView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    private let existingLesson: Lesson?
    private let existingTask: PersonalTask?
    /// Можно ли переключать тип записи (только для новых записей).
    private let kindLocked: Bool

    @State private var kind: EntryKind

    // Поля «Работа» (урок).
    @State private var studentId: UUID?
    @State private var startAt: Date
    @State private var durationMinutes: Int
    @State private var isPaid: Bool
    /// Отметка «Каждую неделю».
    @State private var repeatsWeekly: Bool

    // Поля «Планы» (личная задача).
    @State private var taskTitle: String
    @State private var taskScheduledAt: Date
    @State private var isDone: Bool

    // Общее поле заметки.
    @State private var note: String

    private let durationOptions = [30, 45, 60, 75, 90, 120, 150, 180]

    /// Создание новой записи на указанный день.
    init(newOn day: Date, initialKind: EntryKind = .work) {
        self.existingLesson = nil
        self.existingTask = nil
        self.kindLocked = false
        _kind = State(initialValue: initialKind)
        _studentId = State(initialValue: nil)
        _startAt = State(initialValue: day)
        _durationMinutes = State(initialValue: 60)
        _isPaid = State(initialValue: false)
        _repeatsWeekly = State(initialValue: false)
        _taskTitle = State(initialValue: "")
        _taskScheduledAt = State(initialValue: day)
        _isDone = State(initialValue: false)
        _note = State(initialValue: "")
    }

    /// Редактирование существующего урока.
    init(lesson: Lesson) {
        self.existingLesson = lesson
        self.existingTask = nil
        self.kindLocked = true
        _kind = State(initialValue: .work)
        _studentId = State(initialValue: lesson.studentId)
        _startAt = State(initialValue: lesson.startAt)
        _durationMinutes = State(initialValue: lesson.durationMinutes)
        _isPaid = State(initialValue: lesson.isPaid)
        _repeatsWeekly = State(initialValue: lesson.repeatsWeekly)
        _taskTitle = State(initialValue: "")
        _taskScheduledAt = State(initialValue: lesson.startAt)
        _isDone = State(initialValue: false)
        _note = State(initialValue: lesson.note ?? "")
    }

    /// Редактирование существующей личной задачи.
    init(task: PersonalTask) {
        self.existingLesson = nil
        self.existingTask = task
        self.kindLocked = true
        _kind = State(initialValue: .plans)
        _studentId = State(initialValue: nil)
        _startAt = State(initialValue: task.scheduledAt)
        _durationMinutes = State(initialValue: 60)
        _isPaid = State(initialValue: false)
        _repeatsWeekly = State(initialValue: false)
        _taskTitle = State(initialValue: task.title)
        _taskScheduledAt = State(initialValue: task.scheduledAt)
        _isDone = State(initialValue: task.isDone)
        _note = State(initialValue: task.note ?? "")
    }

    private var isEditing: Bool { existingLesson != nil || existingTask != nil }

    private var navigationTitle: String {
        if existingLesson != nil { return "Урок" }
        if existingTask != nil { return "Задача" }
        return "Новая запись"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if !kindLocked {
                        Picker("Тип", selection: $kind) {
                            ForEach(EntryKind.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("entryTypePicker")
                    }

                    switch kind {
                    case .work: workFields
                    case .plans: plansFields
                    }

                    if isEditing {
                        Button("Удалить", role: .destructive) { delete() }
                            .buttonStyle(.plain)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                    .fill(Theme.destructive.opacity(0.10))
                            )
                    }
                }
                .padding(Theme.Spacing.lg)
                .centeredContent(maxWidth: 560)
            }
            .screenBackground()
            .tint(Theme.accent)
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveLessonButton")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 520, idealHeight: 600)
        #endif
    }

    // MARK: - Поля «Работа»

    @ViewBuilder
    private var workFields: some View {
        SectionCard(title: "Ученик") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if env.students.isEmpty {
                    Text("Добавьте учеников на вкладке «Ученики».")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Picker("Ученик", selection: $studentId) {
                    Text("Выберите").tag(Optional<UUID>.none)
                    ForEach(env.students) { student in
                        Text(student.name).tag(Optional(student.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("lessonStudentPicker")
            }
        }

        SectionCard(title: "Время") {
            VStack(spacing: Theme.Spacing.md) {
                DatePicker("Начало", selection: $startAt)
                RowDivider()
                Picker("Длительность", selection: $durationMinutes) {
                    ForEach(durationOptions, id: \.self) { min in
                        Text("\(min) мин").tag(min)
                    }
                }
            }
            .foregroundStyle(Theme.ink)
        }

        SectionCard(title: "Повторение") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Toggle(isOn: $repeatsWeekly) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "repeat")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(repeatsWeekly ? Theme.accent : Theme.outline)
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill((repeatsWeekly ? Theme.accent : Theme.outline).opacity(0.14))
                            )
                        Text("Каждую неделю")
                            .foregroundStyle(Theme.ink)
                    }
                }
                .accessibilityIdentifier("lessonWeeklyRepeatSwitch")

                Text(repeatHint)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(.easeInOut(duration: 0.2), value: repeatsWeekly)
        }

        SectionCard(title: "Оплата") {
            Toggle("Занятие оплачено", isOn: $isPaid)
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("lessonPaidSwitch")
        }

        SectionCard(title: "Заметка") {
            TextField("Тема, домашнее задание…", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: - Поля «Планы»

    @ViewBuilder
    private var plansFields: some View {
        SectionCard(title: "Задача") {
            TextField("Что нужно сделать", text: $taskTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("taskTitleField")
        }

        SectionCard(title: "Когда") {
            DatePicker("Дата и время", selection: $taskScheduledAt)
                .foregroundStyle(Theme.ink)
        }

        SectionCard {
            Toggle("Выполнено", isOn: $isDone)
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("taskDoneSwitch")
        }

        SectionCard(title: "Заметка") {
            TextField("Детали…", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .foregroundStyle(Theme.ink)
        }
    }

    /// Время начала, каким оно попадёт в расписание (шаг 15 минут).
    private var plannedStart: Date {
        LessonScheduling.snappedStart(startAt, calendar: env.calendar)
    }

    /// Подсказка под отметкой: что произойдёт с расписанием после сохранения.
    private var repeatHint: String {
        if repeatsWeekly {
            let weekday = Formatters.weekdayFull.string(from: plannedStart).lowercased()
            let time = Formatters.time.string(from: plannedStart)
            return "Занятие встанет в расписание на год вперёд: \(weekday), \(time). "
                + "Заметка и оплата остаются только у этой записи."
        }
        if existingLesson?.repeatsWeekly == true {
            return "Повторы со следующей недели будут убраны из расписания."
        }
        return "Занятие останется только в выбранный день."
    }

    private var canSave: Bool {
        switch kind {
        case .work: return studentId != nil
        case .plans: return !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - Действия

    private func save() {
        switch kind {
        case .work:
            guard let studentId else { return }
            // Отметка «Каждую неделю» и есть серия: включённая заводит новую,
            // снятая обнуляет ссылку, и повторов у занятия больше нет.
            let seriesId: UUID? = repeatsWeekly ? (existingLesson?.seriesId ?? UUID()) : nil
            let lesson = Lesson(
                id: existingLesson?.id ?? UUID(),
                studentId: studentId,
                startAt: plannedStart,
                durationMinutes: durationMinutes,
                isPaid: isPaid,
                note: note.isEmpty ? nil : note,
                seriesId: seriesId,
                createdAt: existingLesson?.createdAt ?? Date()
            )
            let wasPaid = existingLesson?.isPaid ?? false
            Task {
                await env.saveLesson(lesson, previousSeriesId: existingLesson?.seriesId)
                // Синхронизируем абонемент с отметкой «Занятие оплачено».
                if let student = env.student(for: studentId), student.workFormat == .subscription {
                    if !wasPaid && isPaid {
                        await env.consumePaidLesson(for: student)
                    } else if wasPaid && !isPaid {
                        await env.restorePaidLesson(for: student)
                    }
                }
                dismiss()
            }
        case .plans:
            let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let task = PersonalTask(
                id: existingTask?.id ?? UUID(),
                title: trimmed,
                scheduledAt: taskScheduledAt,
                note: note.isEmpty ? nil : note,
                isDone: isDone,
                colorHex: existingTask?.colorHex ?? PersonalTask.defaultColorHex,
                createdAt: existingTask?.createdAt ?? Date()
            )
            Task {
                await env.saveTask(task)
                dismiss()
            }
        }
    }

    private func delete() {
        Task {
            if let existingLesson {
                await env.deleteLesson(existingLesson)
            } else if let existingTask {
                await env.deleteTask(existingTask)
            }
            dismiss()
        }
    }
}
