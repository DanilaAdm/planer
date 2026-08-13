import SwiftUI
import PlannerCore

/// Форма создания и правки заметки недели.
///
/// В строке дневника текст обрезается по ширине слота, поэтому целиком он виден
/// именно здесь — по тапу на строку.
struct WeekNoteEditorView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    private let existing: WeekNote?
    /// Неделя, к которой относится заметка (понедельник, 00:00).
    private let weekStart: Date

    @State private var text: String

    /// Новая заметка на неделе, содержащей `day`.
    init(newOn day: Date, calendar: Calendar) {
        self.existing = nil
        self.weekStart = WeekNote.weekStart(containing: day, calendar: calendar)
        _text = State(initialValue: "")
    }

    /// Правка существующей заметки.
    init(note: WeekNote) {
        self.existing = note
        self.weekStart = note.weekStart
        _text = State(initialValue: note.text)
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    SectionCard(title: "Заметка") {
                        TextField("О чём не забыть на этой неделе", text: $text, axis: .vertical)
                            .lineLimit(3...8)
                            .foregroundStyle(Theme.ink)
                            .accessibilityIdentifier("weekNoteTextField")
                    }

                    Text("Неделя с \(Formatters.fullDate.string(from: weekStart))")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)

                    if existing != nil {
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
                            .accessibilityIdentifier("deleteWeekNoteButton")
                    }
                }
                .padding(Theme.Spacing.lg)
                .centeredContent(maxWidth: 560)
            }
            .screenBackground()
            .tint(Theme.accent)
            .navigationTitle(existing == nil ? "Новая заметка" : "Заметка")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(trimmed.isEmpty)
                        .accessibilityIdentifier("saveWeekNoteButton")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 320, idealHeight: 380)
        #endif
    }

    // MARK: - Действия

    private func save() {
        let value = trimmed
        guard !value.isEmpty else { return }
        let note = WeekNote(
            id: existing?.id ?? UUID(),
            weekStart: weekStart,
            text: value,
            createdAt: existing?.createdAt ?? Date()
        )
        Task {
            await env.saveWeekNote(note)
            dismiss()
        }
    }

    private func delete() {
        guard let existing else { return }
        Task {
            await env.deleteWeekNote(existing)
            dismiss()
        }
    }
}
