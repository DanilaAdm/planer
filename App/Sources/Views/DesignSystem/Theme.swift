import SwiftUI

/// Единая система дизайна приложения.
///
/// Токены извлечены из оформления «недельного дневника» (`DiaryWeekView`),
/// которое является визуальным эталоном. Все остальные экраны используют эти
/// значения, чтобы приложение читалось как один цельный продукт.
enum Theme {

    // MARK: - Цвета

    /// Основной фон экрана — очень светлый тёплый серый.
    static let background = Color(hex: "#ECEDF4")
    /// Фон карточек и поверхностей — почти белый с лёгким оттенком.
    static let surface = Color(hex: "#FBFBFE")
    /// Приподнятая поверхность (белая) для акцентных карточек.
    static let surfaceRaised = Color.white

    /// Основной интерактивный акцент — спокойный синий (кнопки, выбор, ссылки).
    static let accent = Color(hex: "#4C7DF0")
    /// Декоративный тонкий контур — мягкий коралл (из дневника).
    static let outline = Color(hex: "#EF9F8E")

    // MARK: - Фирменный оранжевый

    /// Фирменный рыже-оранжевый: верхняя панель разделов и активные сегменты.
    static let brand = Color(hex: "#E5813F")
    /// Тёмный край фирменного цвета — текст и контуры поверх светлых подложек.
    static let brandDeep = Color(hex: "#C15C25")
    /// Светлая тёплая поверхность под фирменные элементы: дорожка переключателя
    /// режимов заметна и на белой карточке, и на сером фоне экрана.
    static let brandSurface = Color(hex: "#F9E7D9")

    /// Заливка активной «пилюли» — тёплый градиент, читаемый под белым текстом.
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#E98A47"), Color(hex: "#D3672D")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Верх шапки окна. Этим же цветом закрашивается заголовок окна на macOS,
    /// чтобы заголовок и панель разделов читались как одна тёплая полоса.
    static let topBarTop = Color(hex: "#FFF4EA")
    /// Низ шапки окна — чуть более насыщенный персиковый.
    static let topBarBottom = Color(hex: "#FAE1CD")

    /// Подложка верхней панели разделов — мягкий переход из кремового в персиковый.
    static var topBarGradient: LinearGradient {
        LinearGradient(colors: [topBarTop, topBarBottom], startPoint: .top, endPoint: .bottom)
    }

    /// Основной текст — приглушённый серо-индиго.
    static let ink = Color(hex: "#33417E")
    /// Вторичный текст (заметно читаемый).
    static var inkSecondary: Color { ink.opacity(0.72) }
    /// Мягкий вторичный текст.
    static var inkSoft: Color { ink.opacity(0.55) }
    /// Разделители и тонкие линии.
    static var divider: Color { ink.opacity(0.12) }

    /// Успех / оплачено — мягкий зелёный.
    static let success = Color(hex: "#3FA971")
    /// Предупреждение / не оплачено — тёплая охра.
    static let warning = Color(hex: "#E0A649")
    /// Деструктивное действие — красный.
    static let destructive = Color(hex: "#E5484D")
    /// Внимание: у ученика заканчивается абонемент — тёплый терракотовый коралл.
    static let attention = Color(hex: "#DD6B4C")
    /// Поверхность карточки в состоянии «абонемент на исходе» — почти белая с
    /// коралловым оттенком. Цвет непрозрачный, чтобы не смешиваться с фоном экрана.
    static let attentionSurface = Color(hex: "#FDF1EC")

    // MARK: - Отступы

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Скругления

    enum Radius {
        static let chip: CGFloat = 8
        static let control: CGFloat = 10
        static let section: CGFloat = 12
        static let card: CGFloat = 16
    }

    // MARK: - Контуры и тени

    enum Stroke {
        static let hairline: CGFloat = 1
        static let outline: CGFloat = 1.2
    }

    /// Мягкая, минимальная тень карточек.
    enum Shadow {
        static let color = Color(hex: "#33417E").opacity(0.10)
        static let radius: CGFloat = 10
        static let y: CGFloat = 4
    }

    /// Максимальная ширина контента (для центрирования на macOS/iPad).
    static let contentMaxWidth: CGFloat = 680
}
