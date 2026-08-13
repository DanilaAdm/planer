import SwiftUI

// MARK: - Карточка

/// Базовый контейнер-карточка: светлая поверхность, скругление,
/// тонкий контур и минимальная тень. Основной строительный блок дизайна.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.lg
    var cornerRadius: CGFloat = Theme.Radius.card
    var showsShadow: Bool = true
    /// Заливка поверхности: можно затонировать для акцентных состояний.
    var fill: Color = Theme.surface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.divider, lineWidth: Theme.Stroke.hairline)
            )
            .shadow(
                color: showsShadow ? Theme.Shadow.color : .clear,
                radius: showsShadow ? Theme.Shadow.radius : 0,
                x: 0,
                y: showsShadow ? Theme.Shadow.y : 0
            )
    }
}

extension View {
    /// Обернуть содержимое в стандартную карточку.
    func card(padding: CGFloat = Theme.Spacing.lg,
              cornerRadius: CGFloat = Theme.Radius.card,
              showsShadow: Bool = true,
              fill: Color = Theme.surface) -> some View {
        Card(padding: padding, cornerRadius: cornerRadius, showsShadow: showsShadow, fill: fill) { self }
    }
}

// MARK: - Заголовки

/// Крупный заголовок страницы с необязательным действием справа.
struct PageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer(minLength: Theme.Spacing.md)
            trailing
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

/// Подпись секции над карточкой/группой.
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.outline)
    }
}

/// Секция-карточка: подпись + сгруппированное содержимое в карточке.
struct SectionCard<Content: View>: View {
    var title: String?
    var padding: CGFloat = Theme.Spacing.lg
    /// Акцентное состояние секции (например, «абонемент на исходе»):
    /// коралловая заливка и кольцо вокруг самой карточки, без подписи секции.
    var attention: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let title {
                SectionHeader(title: title)
                    .padding(.leading, Theme.Spacing.xs)
            }
            content
                .card(padding: padding, fill: attention ? Theme.attentionSurface : Theme.surface)
                .attentionRing(attention)
        }
    }
}

// MARK: - Период календаря

/// Плашка текущего периода: месяц в неделе и в сетке месяца, дата в дне.
///
/// Единственное место, где календарь показывает выбранный период, поэтому
/// выглядит одинаково во всех трёх режимах.
struct CalendarPeriodPlate: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.outline, lineWidth: Theme.Stroke.outline)
                    .allowsHitTesting(false)
            )
    }
}

// MARK: - Чипы / бейджи

/// Небольшой статусный чип (оплачено / не оплачено / выполнено и т.п.).
struct StatusChip: View {
    enum Kind {
        case success, warning, neutral, accent, attention, custom(Color)

        var color: Color {
            switch self {
            case .success: return Theme.success
            case .warning: return Theme.warning
            case .neutral: return Theme.inkSoft
            case .accent: return Theme.accent
            case .attention: return Theme.attention
            case .custom(let c): return c
            }
        }
    }

    let text: String
    var systemImage: String?
    var kind: Kind = .neutral

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(kind.color)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous).fill(kind.color.opacity(0.14))
        )
    }
}

/// Цветной бейдж-идентификатор ученика (кружок цвета).
struct StudentDot: View {
    let colorHex: String
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
            )
    }
}

/// Метка «у ученика заканчивается абонемент»: остался последний оплаченный урок
/// или уже ни одного. Единый знак подсветки во всех разделах приложения.
struct LastLessonBadge: View {
    /// Подпись рядом с иконкой. В тесных местах (сетка календаря, строка дневника)
    /// не задаётся — там метка остаётся одной иконкой.
    var title: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hourglass")
                .font(.system(size: 10, weight: .bold))
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Theme.attention)
        .padding(.horizontal, title == nil ? 5 : Theme.Spacing.sm)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous).fill(Theme.attention.opacity(0.16))
        )
        .fixedSize()
        .accessibilityElement()
        .accessibilityLabel(title ?? "Абонемент заканчивается")
        .accessibilityIdentifier("lastLessonBadge")
    }
}

/// Метка «занятие повторяется каждую неделю» — та же отметка, что стоит в
/// редакторе записи. Единый знак повторения во всех разделах приложения.
struct WeeklyRepeatMark: View {
    /// Подпись рядом с иконкой. В тесных местах (строка дневника, блок
    /// календаря) не задаётся — там метка остаётся одной иконкой.
    var title: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "repeat")
                .font(.system(size: 9, weight: .bold))
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, title == nil ? 5 : Theme.Spacing.sm)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous).fill(Theme.accent.opacity(0.14))
        )
        .fixedSize()
        .accessibilityElement()
        .accessibilityLabel(title ?? "Повторяется каждую неделю")
        .accessibilityIdentifier("weeklyRepeatMark")
    }
}

/// Выделенное значение (деньги / счётчики).
struct ValueLabel: View {
    let text: String
    var size: Font = .title3
    var color: Color = Theme.ink

    var body: some View {
        Text(text)
            .font(size.weight(.bold))
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

// MARK: - Кнопки

/// Основная кнопка — синяя заливка.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.accent.opacity(isEnabled ? 1 : 0.4))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }
}

/// Вторичная кнопка — тонкий контур на светлом фоне.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.accent.opacity(isEnabled ? 1 : 0.4))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.25), lineWidth: Theme.Stroke.hairline)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primaryFilled: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondarySoft: SecondaryButtonStyle { SecondaryButtonStyle() }
}

// MARK: - Сегментированный переключатель

/// Переключатель режимов в фирменных цветах.
///
/// Системный `.pickerStyle(.segmented)` на светлом фоне почти невидим: у него нет
/// собственной подложки, а невыбранные пункты выглядят как выключенные. Здесь
/// дорожка залита тёплым оттенком с тонким контуром, поэтому контрол читается как
/// отдельный элемент, а выбранный пункт подсвечен светлой «пилюлей».
struct SegmentedSelector<Value: Hashable>: View {
    private let items: [Value]
    private let title: (Value) -> String
    @Binding private var selection: Value
    @Namespace private var indicator

    init(items: [Value], selection: Binding<Value>, title: @escaping (Value) -> String) {
        self.items = items
        self._selection = selection
        self.title = title
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                segment(item)
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.brandSurface)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Theme.brand.opacity(0.30), lineWidth: Theme.Stroke.hairline)
                .allowsHitTesting(false)
        )
    }

    private func segment(_ item: Value) -> some View {
        let isSelected = item == selection
        return Button {
            guard !isSelected else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                selection = item
            }
        } label: {
            Text(title(item))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.brandDeep : Theme.ink.opacity(0.62))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Theme.surfaceRaised)
                            .shadow(color: Theme.brandDeep.opacity(0.20), radius: 3, y: 1)
                            .matchedGeometryEffect(id: "segmentedSelection", in: indicator)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title(item))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Поля форм

/// Обёртка строки формы: подпись слева/сверху + произвольный контрол.
struct FormFieldRow<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(Theme.outline)
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            content
        }
    }
}

/// Тонкий разделитель между строками внутри карточки.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: Theme.Stroke.hairline)
    }
}

// MARK: - Пустое состояние

/// Блок пустого состояния в едином стиле.
struct EmptyStateBlock: View {
    let title: String
    let systemImage: String
    var message: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.outline)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Компоновка

extension View {
    /// Центрировать контент и ограничить ширину (для macOS/широких экранов),
    /// чтобы избежать растянутых пустых макетов.
    func centeredContent(maxWidth: CGFloat = Theme.contentMaxWidth) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }

    /// Общий фон экрана в стиле дизайн-системы.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }

    /// Коралловое кольцо-подсветка вокруг карточки или строки: ученик, у которого
    /// заканчивается абонемент. При `active == false` вид не меняется.
    func attentionRing(_ active: Bool, cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(active ? Theme.attention.opacity(0.6) : .clear,
                              lineWidth: Theme.Stroke.outline)
        )
        .animation(.easeInOut(duration: 0.2), value: active)
    }
}
