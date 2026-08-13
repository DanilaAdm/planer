import SwiftUI
import PlannerCore

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month = "Месяц"
    case week = "Неделя"
    case day = "День"
    var id: String { rawValue }

    var scope: CalendarScope {
        switch self {
        case .month: return .month
        case .week: return .week
        case .day: return .day
        }
    }
}

/// Запрос на создание новой записи планера на конкретный день.
struct NewEntryRequest: Identifiable {
    let id = UUID()
    let day: Date
}

/// Запрос на создание заметки для недели, содержащей `day`.
struct NewNoteRequest: Identifiable {
    let id = UUID()
    let day: Date
}

struct CalendarRootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var editingLesson: Lesson?
    @State private var editingTask: PersonalTask?
    @State private var creating: NewEntryRequest?
    @State private var editingNote: WeekNote?
    @State private var creatingNote: NewNoteRequest?

    private var mode: CalendarViewMode { env.calendarMode }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                content
            }
            .navigationTitle("Календарь")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        creating = NewEntryRequest(day: defaultNewLessonDate())
                    } label: {
                        Label("Добавить", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addLessonButton")
                }
            }
            .sheet(item: $editingLesson) { lesson in
                PlannerEntryEditorView(lesson: lesson)
            }
            .sheet(item: $editingTask) { task in
                PlannerEntryEditorView(task: task)
            }
            .sheet(item: $creating) { request in
                PlannerEntryEditorView(newOn: request.day)
            }
            .sheet(item: $editingNote) { note in
                WeekNoteEditorView(note: note)
            }
            .sheet(item: $creatingNote) { request in
                WeekNoteEditorView(newOn: request.day, calendar: env.calendar)
            }
            .task(id: mode) { await env.loadLessons(for: env.selectedDate, scope: mode.scope) }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                navButton(systemName: "chevron.left", identifier: "calendarPreviousButton") { shift(by: -1) }
                Spacer(minLength: Theme.Spacing.sm)
                SegmentedSelector(items: CalendarViewMode.allCases, selection: $env.calendarMode) {
                    $0.rawValue
                }
                .frame(maxWidth: 320)
                Spacer(minLength: Theme.Spacing.sm)
                navButton(systemName: "chevron.right", identifier: "calendarNextButton") { shift(by: 1) }
            }

            if env.students.isEmpty {
                Text("Добавьте учеников на вкладке «Ученики», чтобы создавать уроки.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
    }

    private func navButton(systemName: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.brandDeep)
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(Theme.brand.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .month:
            MonthGridView(onSelectDay: { day in
                env.selectedDate = day
                env.calendarMode = .day
            })
        case .week:
            DiaryWeekView(
                onSelectDay: { day in
                    env.selectedDate = day
                    env.calendarMode = .day
                },
                onEditLesson: { editingLesson = $0 },
                onEditTask: { editingTask = $0 },
                onAdd: { creating = NewEntryRequest(day: $0) },
                onEditNote: { editingNote = $0 },
                onAddNote: { creatingNote = NewNoteRequest(day: env.selectedDate) }
            )
        case .day:
            DayView(
                onEditLesson: { editingLesson = $0 },
                onCreateAt: { creating = NewEntryRequest(day: $0) }
            )
        }
    }

    private func shift(by amount: Int) {
        let component: Calendar.Component
        switch mode {
        case .month: component = .month
        case .week: component = .weekOfYear
        case .day: component = .day
        }
        if let newDate = env.calendar.date(byAdding: component, value: amount, to: env.selectedDate) {
            env.selectedDate = newDate
            Task { await env.loadLessons(for: newDate, scope: mode.scope) }
        }
    }

    private func defaultNewLessonDate() -> Date {
        let cal = env.calendar
        let base = cal.startOfDay(for: env.selectedDate)
        return cal.date(byAdding: .hour, value: 10, to: base) ?? env.selectedDate
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
