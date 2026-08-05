import SwiftUI
import PlannerCore

/// Блок урока в календаре: мягкая тонированная карточка с цветовым акцентом
/// ученика, именем, временем и удобной отметкой оплаты.
struct LessonBlockView: View {
    @EnvironmentObject private var env: AppEnvironment
    let lesson: Lesson
    var compact: Bool = false
    /// Высота слота во временной сетке. Карточка занимает ровно её, а содержимое
    /// подстраивается, чтобы блок не заезжал на соседние часы.
    var height: CGFloat?

    /// Ниже этой высоты полная раскладка (имя + время + кнопка оплаты) не помещается.
    private static let fullLayoutMinHeight: CGFloat = 56

    private var student: Student? { env.student(for: lesson.studentId) }
    private var colorHex: String { student?.colorHex ?? HexColor.palette[0] }
    private var color: Color { Color(hex: colorHex) }
    /// У ученика заканчивается абонемент — блок помечается кораллом.
    private var isEnding: Bool { student?.isPaidPackageEnding ?? false }

    private var isTight: Bool {
        if compact { return true }
        guard let height else { return false }
        return height < Self.fullLayoutMinHeight
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
        HStack(spacing: 0) {
            // Цветовая полоса-идентификатор ученика.
            Rectangle()
                .fill(color)
                .frame(width: 4)

            content
                .padding(.horizontal, isTight ? 6 : 8)
                .padding(.vertical, isTight ? 4 : 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: height, alignment: .top)
        .clipShape(shape)
        .background(shape.fill(color.opacity(0.12)))
        // Контур «абонемент на исходе» важнее контура оплаты: сама оплата и так
        // видна капсулой «Оплачено» (и зелёной печатью в компактном режиме).
        .overlay(shape.strokeBorder(strokeColor, lineWidth: strokeWidth))
        .animation(.easeInOut(duration: 0.2), value: isEnding)
    }

    @ViewBuilder
    private var content: some View {
        if isTight {
            HStack(spacing: 4) {
                title(font: .caption2.bold())
                Spacer(minLength: 0)
                if isEnding { LastLessonBadge() }
                // Капсула оплаты в короткий слот не помещается — статус показываем иконкой.
                Image(systemName: lesson.isPaid ? "checkmark.seal.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(lesson.isPaid ? Theme.success : Theme.warning)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    title(font: .caption.bold())
                    Spacer(minLength: 0)
                    if isEnding { LastLessonBadge() }
                }
                HStack(spacing: 6) {
                    Text("\(Formatters.time.string(from: lesson.startAt))–\(Formatters.time.string(from: lesson.endAt))")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    controls
                }
            }
        }
    }

    private func title(font: Font) -> some View {
        Text(student?.name ?? "Урок")
            .font(font)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
    }

    private var strokeColor: Color {
        if isEnding { return Theme.attention.opacity(0.7) }
        return lesson.isPaid ? Theme.success.opacity(0.7) : Theme.divider
    }

    private var strokeWidth: CGFloat {
        isEnding || lesson.isPaid ? 1.5 : Theme.Stroke.hairline
    }

    @ViewBuilder
    private var controls: some View {
        let isPaid = lesson.isPaid
        Button {
            Task { await env.toggleLessonPaid(lesson) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11, weight: .bold))
                Text(isPaid ? "Оплачено" : "Не оплачено")
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isPaid ? .white : Theme.warning)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .frame(minHeight: 22)
            .background {
                if isPaid {
                    Capsule().fill(Theme.success)
                } else {
                    Capsule().fill(Theme.warning.opacity(0.14))
                }
            }
            .overlay {
                Capsule().strokeBorder(
                    isPaid ? Color.clear : Theme.warning.opacity(0.4),
                    lineWidth: 1
                )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Занятие оплачено")
        .accessibilityIdentifier("lessonPaidToggle")
    }
}
