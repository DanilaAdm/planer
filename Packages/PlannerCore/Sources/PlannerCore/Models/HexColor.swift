import Foundation

/// RGBA-цвет в компонентах 0...1, независимый от SwiftUI/UIKit.
public struct RGBAColor: Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// Утилиты для конвертации HEX-строк в компоненты цвета и обратно.
public enum HexColor {
    /// Палитра максимально различимых цветов для отметки учеников.
    /// Каждый цвет заметно отличается по тону/яркости от соседних,
    /// чтобы учеников было легко различать с первого взгляда.
    public static let palette: [String] = [
        "#E6194B", // ярко-красный
        "#F58231", // оранжевый
        "#FFB300", // янтарный
        "#FFE119", // жёлтый
        "#BFEF45", // лаймовый
        "#3CB44B", // зелёный
        "#1E7D32", // тёмно-зелёный
        "#42D4F4", // голубой
        "#469990", // бирюзовый
        "#1E90FF", // небесно-синий
        "#4363D8", // синий
        "#000075", // тёмно-синий
        "#911EB4", // фиолетовый
        "#B388FF", // сиреневый
        "#F032E6", // маджента
        "#FF1493", // ярко-розовый
        "#FABED4", // светло-розовый
        "#9A6324", // коричневый
        "#800000", // бордовый
        "#808000", // оливковый
        "#00B3A4", // изумрудный
        "#A9A9A9", // серый
        "#37474F", // тёмно-серый
        "#000000"  // чёрный
    ]

    /// Является ли строка валидным HEX-цветом (#RGB, #RRGGBB, #RRGGBBAA).
    public static func isValid(_ hex: String) -> Bool {
        parse(hex) != nil
    }

    /// Разобрать HEX-строку в компоненты. Поддерживает #RGB, #RRGGBB, #RRGGBBAA
    /// с ведущим "#" или без него. Возвращает nil при некорректном вводе.
    public static func parse(_ hex: String) -> RGBAColor? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }

        guard s.allSatisfy({ $0.isHexDigit }) else { return nil }

        switch s.count {
        case 3: // RGB -> RRGGBB
            s = s.map { "\($0)\($0)" }.joined()
        case 6, 8:
            break
        default:
            return nil
        }

        guard let value = UInt64(s, radix: 16) else { return nil }

        if s.count == 8 {
            let r = Double((value & 0xFF00_0000) >> 24) / 255
            let g = Double((value & 0x00FF_0000) >> 16) / 255
            let b = Double((value & 0x0000_FF00) >> 8) / 255
            let a = Double(value & 0x0000_00FF) / 255
            return RGBAColor(red: r, green: g, blue: b, alpha: a)
        } else {
            let r = Double((value & 0xFF0000) >> 16) / 255
            let g = Double((value & 0x00FF00) >> 8) / 255
            let b = Double(value & 0x0000FF) / 255
            return RGBAColor(red: r, green: g, blue: b, alpha: 1)
        }
    }

    /// Собрать строку "#RRGGBB" из компонентов (альфа отбрасывается).
    public static func string(from color: RGBAColor) -> String {
        let r = Int((color.red * 255).rounded())
        let g = Int((color.green * 255).rounded())
        let b = Int((color.blue * 255).rounded())
        let clamp = { (v: Int) in min(255, max(0, v)) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }

    /// Нормализовать любую валидную запись цвета к виду "#RRGGBB".
    /// Возвращает первый цвет палитры, если строка некорректна.
    public static func normalized(_ hex: String) -> String {
        guard let color = parse(hex) else { return palette[0] }
        return string(from: color)
    }
}
