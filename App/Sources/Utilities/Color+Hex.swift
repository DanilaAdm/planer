import SwiftUI
import PlannerCore
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// Создать цвет из HEX-строки ("#RRGGBB"). При ошибке — серый.
    init(hex: String) {
        guard let rgba = HexColor.parse(hex) else {
            self = .gray
            return
        }
        self = Color(
            .sRGB,
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }

    /// Преобразовать цвет в HEX-строку "#RRGGBB" (альфа отбрасывается).
    func toHex() -> String {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return HexColor.string(from: RGBAColor(red: Double(r), green: Double(g), blue: Double(b), alpha: 1))
        #elseif canImport(AppKit)
        let native = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        return HexColor.string(from: RGBAColor(
            red: Double(native.redComponent),
            green: Double(native.greenComponent),
            blue: Double(native.blueComponent),
            alpha: 1
        ))
        #else
        return HexColor.palette[0]
        #endif
    }

    /// Контрастный цвет текста (чёрный/белый) для читаемости на фоне HEX-цвета.
    static func readableText(on hex: String) -> Color {
        guard let rgba = HexColor.parse(hex) else { return .primary }
        // Относительная яркость по WCAG (упрощённо).
        let luminance = 0.299 * rgba.red + 0.587 * rgba.green + 0.114 * rgba.blue
        return luminance > 0.6 ? .black : .white
    }
}
