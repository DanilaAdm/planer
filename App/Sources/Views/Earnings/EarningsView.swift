import SwiftUI
import PlannerCore

struct EarningsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var monthLessons: [Lesson] = []

    private var monthDate: Date { env.earningsMonth }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    periodCard
                    totalCard
                    studentsSection
                }
                .padding(Theme.Spacing.lg)
                .centeredContent()
            }
            .screenBackground()
            .navigationTitle("Заработок")
            .task(id: monthKey) { await reload() }
            .refreshable { await reload() }
        }
    }

    private var periodCard: some View {
        Card {
            HStack(spacing: Theme.Spacing.md) {
                monthButton(systemName: "chevron.left") { shiftMonth(-1) }
                Spacer(minLength: 0)
                Text(Formatters.monthYear.string(from: monthDate).capitalized)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                monthButton(systemName: "chevron.right") { shiftMonth(1) }
            }
        }
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.accent.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }

    private var totalCard: some View {
        SectionCard(title: "Итого за месяц") {
            HStack(alignment: .firstTextBaseline) {
                Text("Всего заработано")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Text(Formatters.money(total))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("totalEarnings")
            }
        }
    }

    @ViewBuilder
    private var studentsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "По ученикам")
                .padding(.leading, Theme.Spacing.xs)
            if earnings.isEmpty {
                EmptyStateBlock(
                    title: "Нет данных за этот месяц",
                    systemImage: "chart.bar",
                    message: nil
                )
                .card()
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(earnings, id: \.student.id) { item in
                        EarningsRow(item: item).card()
                    }
                }
            }
        }
    }

    private var components: DateComponents {
        env.calendar.dateComponents([.year, .month], from: monthDate)
    }

    private var monthKey: String {
        "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private var earnings: [StudentEarnings] {
        EarningsCalculator.earningsByStudent(
            students: env.students,
            lessons: monthLessons,
            month: components.month ?? 1,
            year: components.year ?? 2026,
            calendar: env.calendar
        ).filter { $0.lessonsCount > 0 || $0.amount > 0 }
    }

    private var total: Decimal {
        earnings.reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func shiftMonth(_ delta: Int) {
        if let d = env.calendar.date(byAdding: .month, value: delta, to: monthDate) {
            env.earningsMonth = d
        }
    }

    private func reload() async {
        let range = CalendarRange.month(containing: monthDate, calendar: env.calendar)
        monthLessons = await env.monthLessons(in: range)
    }
}

private struct EarningsRow: View {
    let item: StudentEarnings

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            StudentDot(colorHex: item.student.colorHex, size: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.student.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text("оплачено \(item.paidLessonsCount) из \(item.lessonsCount) · \(item.student.workFormat.localizedTitle)")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: Theme.Spacing.sm)
            ValueLabel(text: Formatters.money(item.amount), size: .headline)
        }
    }
}
