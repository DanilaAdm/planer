import SwiftUI
import PlannerCore

/// Сетка месяца. Тап по дню открывает День.
struct MonthGridView: View {
    @EnvironmentObject private var env: AppEnvironment
    let onSelectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                CalendarPeriodPlate(text: Formatters.monthYear.string(from: env.selectedDate).capitalized)
                Card(padding: Theme.Spacing.md) {
                    VStack(spacing: Theme.Spacing.sm) {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(weekdaySymbols, id: \.self) { symbol in
                                Text(symbol.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.outline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                                if let day {
                                    dayCell(day)
                                        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                                        .onTapGesture { onSelectDay(day) }
                                } else {
                                    Color.clear.frame(height: 64)
                                }
                            }
                        }
                    }
                }
                .centeredContent()
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .task { await env.loadLessons(for: env.selectedDate, scope: .month) }
    }

    private func dayCell(_ day: Date) -> some View {
        let dayLessons = env.lessons(on: day)
        let isToday = env.calendar.isDateInToday(day)
        return VStack(spacing: 3) {
            Text(Formatters.dayNumber.string(from: day))
                .font(.callout)
                .fontWeight(isToday ? .bold : .medium)
                .foregroundStyle(isToday ? Theme.accent : Theme.ink)
                .frame(maxWidth: .infinity, alignment: .trailing)
            // Шаг 4 вместо 3: кольцо подсветки шире точки и не должно задевать соседей.
            HStack(spacing: 4) {
                ForEach(dayLessons.prefix(4)) { lesson in
                    let isEnding = env.student(for: lesson.studentId)?.isPaidPackageEnding ?? false
                    Circle()
                        .fill(Color(hex: env.studentColorHex(for: lesson.studentId)))
                        .frame(width: 6, height: 6)
                        .overlay {
                            if isEnding {
                                Circle()
                                    .strokeBorder(Theme.attention, lineWidth: 1)
                                    .padding(-2)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(isToday ? Theme.accent.opacity(0.10) : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(isToday ? Theme.accent.opacity(0.4) : Theme.divider,
                              lineWidth: Theme.Stroke.hairline)
        )
    }

    private var weekdaySymbols: [String] {
        var cal = env.calendar
        cal.locale = Locale(identifier: "ru_RU")
        let symbols = cal.shortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Дни месяца с ведущими пустыми ячейками до первого дня недели.
    private var monthDays: [Date?] {
        let cal = env.calendar
        let range = CalendarRange.month(containing: env.selectedDate, calendar: cal)
        let firstDay = range.start
        let daysInMonth = cal.range(of: .day, in: .month, for: firstDay)?.count ?? 30

        let weekday = cal.component(.weekday, from: firstDay)
        let leading = (weekday - cal.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<daysInMonth {
            cells.append(cal.date(byAdding: .day, value: offset, to: firstDay))
        }
        return cells
    }
}
