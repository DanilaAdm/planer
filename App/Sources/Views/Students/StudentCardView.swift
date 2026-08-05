import SwiftUI
import PlannerCore

/// Карточка ученика: цена, формат, счётчик оплаченных уроков (списание урока
/// происходит по отметке «Занятие оплачено» в планере) и Google-документ.
struct StudentCardView: View {
    @EnvironmentObject private var env: AppEnvironment
    let studentId: UUID

    @State private var showEditor = false
    @State private var showDoc = false

    private var student: Student? { env.student(for: studentId) }

    var body: some View {
        Group {
            if let student {
                content(for: student)
            } else {
                ContentUnavailableView("Ученик не найден", systemImage: "person.slash")
            }
        }
        .navigationTitle(student?.name ?? "Ученик")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let student {
                ToolbarItem(placement: .primaryAction) {
                    Button("Изменить") { showEditor = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let url = student.googleDocURL, url.scheme != nil {
                        Button {
                            showDoc = true
                        } label: {
                            Label("Документ", systemImage: "doc.text")
                        }
                        .accessibilityLabel("Открыть документ")
                        .accessibilityIdentifier("openDocToolbarButton")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let student { StudentEditorView(student: student) }
        }
        .sheet(isPresented: $showDoc) {
            if let student, let url = student.googleDocURL {
                DocReaderView(url: url, fallbackTitle: student.name)
            }
        }
    }

    @ViewBuilder
    private func content(for student: Student) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                headerCard(student)
                if student.workFormat == .subscription {
                    paidLessonsCard(student)
                }
                docCard(student)
            }
            .padding(Theme.Spacing.lg)
            .centeredContent()
        }
        .screenBackground()
    }

    private func headerCard(_ student: Student) -> some View {
        Card {
            HStack(spacing: Theme.Spacing.lg) {
                Circle()
                    .fill(Color(hex: student.colorHex))
                    .frame(width: 52, height: 52)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
                VStack(alignment: .leading, spacing: 6) {
                    Text(student.name)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    StudentStatusChips(student: student)
                }
                Spacer(minLength: Theme.Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    ValueLabel(text: Formatters.money(student.pricePerLesson), color: Theme.accent)
                    Text("за урок")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }

    private func paidLessonsCard(_ student: Student) -> some View {
        SectionCard(title: "Оплаченные уроки", attention: student.isPaidPackageEnding) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(student.paidLessonsIndicator)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("paidIndicator")
                    Text("использовано / оплачено")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Button {
                        Task { await env.restorePaidLesson(for: student) }
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Вернуть урок в абонемент")
                    .accessibilityIdentifier("restorePaidLessonButton")
                    .disabled(student.lessonsUsed == 0)
                    .opacity(student.lessonsUsed == 0 ? 0.4 : 1)
                }
                subscriptionProgress(student)
                StatusChip(
                    text: "Осталось \(student.paidLessonsRemaining)",
                    systemImage: "calendar",
                    kind: student.isPaidPackageEnding ? .attention : .success
                )
            }
        }
    }

    @ViewBuilder
    private func subscriptionProgress(_ student: Student) -> some View {
        let total = max(student.paidLessonsTotal, 1)
        let fraction = min(1, Double(student.lessonsUsed) / Double(total))
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.divider)
                Capsule()
                    .fill(Color(hex: student.colorHex))
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private func docCard(_ student: Student) -> some View {
        SectionCard(title: "Google-документ") {
            if let url = student.googleDocURL, url.scheme != nil {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Пройденный материал и предстоящие темы.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                    Button {
                        showDoc = true
                    } label: {
                        Label("Открыть документ", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.primaryFilled)
                    .accessibilityIdentifier("openDocButton")
                    Link("Открыть в браузере", destination: url)
                        .font(.footnote)
                        .tint(Theme.accent)
                        .accessibilityIdentifier("openDocInBrowserLink")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Ссылка на документ не указана. Добавьте её в редакторе ученика.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}