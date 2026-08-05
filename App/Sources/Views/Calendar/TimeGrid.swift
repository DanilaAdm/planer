import SwiftUI
import PlannerCore

/// Геометрия временной сетки (день/неделя): перевод времени в координаты и обратно.
struct TimeGridMetrics {
    var startHour: Int = 7
    var endHour: Int = 23
    var hourHeight: CGFloat = 64

    var hoursCount: Int { max(1, endHour - startHour) }
    var totalHeight: CGFloat { CGFloat(hoursCount) * hourHeight }
    var minutePerPoint: CGFloat { 60 / hourHeight }

    /// Y-смещение начала урока внутри дня.
    func yOffset(for date: Date, in day: Date, calendar: Calendar) -> CGFloat {
        let startOfDay = calendar.startOfDay(for: day)
        let minutes = date.timeIntervalSince(startOfDay) / 60
        let minutesFromGridStart = minutes - Double(startHour * 60)
        return CGFloat(minutesFromGridStart) / 60 * hourHeight
    }

    /// Высота блока урока по длительности.
    func height(forDurationMinutes minutes: Int) -> CGFloat {
        max(24, CGFloat(minutes) / 60 * hourHeight)
    }

    /// Дата, соответствующая Y-координате внутри дня (с привязкой к шагу).
    func date(forY y: CGFloat, in day: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: day)
        let minutesFromGridStart = Double(y) * Double(minutePerPoint)
        let totalMinutes = Double(startHour * 60) + minutesFromGridStart
        let date = startOfDay.addingTimeInterval(totalMinutes * 60)
        return LessonScheduling.snappedStart(date, calendar: calendar)
    }
}
