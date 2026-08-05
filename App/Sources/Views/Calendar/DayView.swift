import SwiftUI
import PlannerCore

/// День: детальная временная сетка с перетаскиванием и изменением длительности уроков.
struct DayView: View {
    @EnvironmentObject private var env: AppEnvironment
    let onEditLesson: (Lesson) -> Void
    let onCreateAt: (Date) -> Void

    private let metrics = TimeGridMetrics()
    private let hourColumnWidth: CGFloat = 52

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                CalendarPeriodPlate(text: Formatters.fullDate.string(from: env.selectedDate).capitalized)
                HStack(alignment: .top, spacing: 0) {
                    hourColumn
                    dayColumn
                }
            }
            .padding(Theme.Spacing.md)
            .centeredContent(maxWidth: 720)
        }
        .screenBackground()
        .task { await env.loadLessons(for: env.selectedDate, scope: .day) }
    }

    private var hourColumn: some View {
        VStack(spacing: 0) {
            ForEach(metrics.startHour..<metrics.endHour, id: \.self) { hour in
                Text("\(String(format: "%02d", hour)):00")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(height: metrics.hourHeight, alignment: .top)
                    .accessibilityIdentifier("hourLabel-\(hour)")
            }
        }
        .frame(width: hourColumnWidth)
    }

    private var dayColumn: some View {
        let day = env.selectedDate
        let dayLessons = env.lessons(on: day)
        return ZStack(alignment: .topLeading) {
            gridBackground(day: day)

            ForEach(dayLessons) { lesson in
                DayLessonView(
                    lesson: lesson,
                    day: day,
                    metrics: metrics,
                    onTap: { onEditLesson(lesson) }
                )
            }
        }
        .frame(height: metrics.totalHeight)
        .frame(maxWidth: .infinity)
    }

    private func gridBackground(day: Date) -> some View {
        VStack(spacing: 0) {
            ForEach(metrics.startHour..<metrics.endHour, id: \.self) { hour in
                Rectangle()
                    .fill(Theme.surface.opacity(0.5))
                    .frame(height: metrics.hourHeight)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Theme.divider).frame(height: Theme.Stroke.hairline)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let base = env.calendar.startOfDay(for: day)
                        if let date = env.calendar.date(byAdding: .hour, value: hour, to: base) {
                            onCreateAt(date)
                        }
                    }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.section, style: .continuous)
                .fill(Theme.surface.opacity(0.4))
        )
    }
}

/// Отдельный урок в дне: поддерживает перетаскивание (перенос) и resize (длительность).
private struct DayLessonView: View {
    @EnvironmentObject private var env: AppEnvironment
    let lesson: Lesson
    let day: Date
    let metrics: TimeGridMetrics
    let onTap: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var liveDuration: Int?

    private var duration: Int { liveDuration ?? lesson.durationMinutes }

    var body: some View {
        let baseY = metrics.yOffset(for: lesson.startAt, in: day, calendar: env.calendar)
        LessonBlockView(
            lesson: withDuration(lesson),
            height: metrics.height(forDurationMinutes: duration)
        )
            .overlay(alignment: .bottom) { resizeHandle }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("lessonBlock-\(env.calendar.component(.hour, from: lesson.startAt))")
            .padding(.horizontal, 4)
            .offset(y: baseY + dragOffset)
            .gesture(moveGesture(baseY: baseY))
            .onTapGesture { onTap() }
    }

    private var resizeHandle: some View {
        Capsule()
            .fill(Theme.ink.opacity(0.25))
            .frame(width: 40, height: 5)
            .padding(2)
            .contentShape(Rectangle())
            .gesture(resizeGesture)
            .accessibilityIdentifier("lessonResizeHandle")
    }

    private func moveGesture(baseY: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in dragOffset = value.translation.height }
            .onEnded { value in
                let newY = baseY + value.translation.height
                let newStart = metrics.date(forY: newY, in: day, calendar: env.calendar)
                dragOffset = 0
                Task { await env.saveLesson(LessonScheduling.move(lesson, to: newStart)) }
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let deltaMinutes = Int(value.translation.height * metrics.minutePerPoint)
                liveDuration = LessonScheduling.snappedDuration(lesson.durationMinutes + deltaMinutes)
            }
            .onEnded { _ in
                if let liveDuration {
                    Task { await env.saveLesson(LessonScheduling.resize(lesson, toDurationMinutes: liveDuration)) }
                }
                liveDuration = nil
            }
    }

    private func withDuration(_ lesson: Lesson) -> Lesson {
        var copy = lesson
        copy.durationMinutes = duration
        return copy
    }
}
