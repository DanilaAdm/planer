import SwiftUI
import PlannerCore

struct StudentsListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var editingStudent: Student?
    @State private var showingNew = false

    var body: some View {
        NavigationStack(path: $env.studentsPath) {
            Group {
                if env.students.isEmpty {
                    EmptyStateBlock(
                        title: "Нет учеников",
                        systemImage: "person.2",
                        message: "Нажмите + чтобы добавить первого ученика"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .screenBackground()
                } else {
                    List {
                        ForEach(env.students) { student in
                            ZStack {
                                NavigationLink(value: student) { EmptyView() }.opacity(0)
                                StudentRow(student: student)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 5, leading: Theme.Spacing.lg,
                                                      bottom: 5, trailing: Theme.Spacing.lg))
                            .swipeActions {
                                Button("Изменить") { editingStudent = student }
                                    .tint(Theme.accent)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .screenBackground()
                }
            }
            .navigationTitle("Ученики")
            .navigationDestination(for: Student.self) { student in
                StudentCardView(studentId: student.id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNew = true
                    } label: {
                        Label("Добавить", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addStudentButton")
                }
            }
            .sheet(isPresented: $showingNew) {
                StudentEditorView(student: nil)
            }
            .sheet(item: $editingStudent) { student in
                StudentEditorView(student: student)
            }
            .refreshable { await env.reloadStudents() }
        }
    }

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { env.students[$0] }
        Task {
            for student in toDelete { await env.deleteStudent(student) }
        }
    }
}

private struct StudentRow: View {
    let student: Student

    private var isEnding: Bool { student.isPaidPackageEnding }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            StudentDot(colorHex: student.colorHex, size: 26)

            VStack(alignment: .leading, spacing: 5) {
                Text(student.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                StudentStatusChips(student: student)
            }

            Spacer(minLength: Theme.Spacing.sm)

            VStack(alignment: .trailing, spacing: 5) {
                ValueLabel(text: Formatters.money(student.pricePerLesson), size: .subheadline)
                if student.workFormat == .subscription {
                    StatusChip(
                        text: "Оплачено \(student.paidLessonsIndicator)",
                        systemImage: "creditcard",
                        // При подсветке держим в строке один цвет тревоги, а не два.
                        kind: isEnding ? .attention : .success
                    )
                } else {
                    Text("за урок")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .card(fill: isEnding ? Theme.attentionSurface : Theme.surface)
        .attentionRing(isEnding)
    }
}
