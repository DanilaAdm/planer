// Рисует иконку приложения и раскладывает её по размерам в asset catalog.
//
// Запуск: ./scripts/make_icons.sh
//
// Иконка рисуется кодом, а не хранится картинкой: так она остаётся резкой на всех
// размерах и её легко поменять — правьте цвета и геометрию ниже и перегенерируйте.
// Цвета взяты из App/Sources/Views/DesignSystem/Theme.swift, чтобы иконка
// совпадала с оформлением приложения.

import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let brandLight = color(0xE9_8A_47)
let brandDark = color(0xD3_67_2D)
let ink = color(0x33_41_7E)
let paper = color(0xFF_FF_FF)
let line = color(0xC9_CE_E4)

func makeContext(size: CGFloat) -> CGContext {
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Не удалось создать графический контекст \(size)x\(size)")
    }
    return ctx
}

/// Рисует иконку в системе координат 1024x1024 (начало координат внизу слева).
func drawIcon(in ctx: CGContext) {
    // Скруглённый квадрат подложки. Поля по краям обязательны: на macOS иконка
    // не обрезается системой, форму и отступы задаёт само изображение.
    let bodyInset: CGFloat = 96
    let body = CGRect(x: bodyInset, y: bodyInset,
                      width: canvas - bodyInset * 2,
                      height: canvas - bodyInset * 2)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [brandLight, brandDark] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: body.minX, y: body.maxY),
        end: CGPoint(x: body.maxX, y: body.minY),
        options: []
    )
    // Мягкий блик сверху, чтобы подложка не выглядела плоской.
    let glow = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [color(0xFF_FF_FF, alpha: 0.20), color(0xFF_FF_FF, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        glow,
        start: CGPoint(x: body.midX, y: body.maxY),
        end: CGPoint(x: body.midX, y: body.midY),
        options: []
    )
    ctx.restoreGState()

    // Страница планера.
    let page = CGRect(x: 252, y: 212, width: 520, height: 600)
    let pagePath = CGPath(roundedRect: page, cornerWidth: 56, cornerHeight: 56, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: color(0x1F_25_4A, alpha: 0.28))
    ctx.addPath(pagePath)
    ctx.setFillColor(paper)
    ctx.fillPath()
    ctx.restoreGState()

    // Тёмная шапка страницы. Клип по контуру страницы сам скругляет верхние углы.
    ctx.saveGState()
    ctx.addPath(pagePath)
    ctx.clip()
    ctx.setFillColor(ink)
    ctx.fill(CGRect(x: page.minX, y: page.maxY - 116, width: page.width, height: 116))
    ctx.restoreGState()

    // Три строки списка. Верхняя — отмеченная.
    let boxSide: CGFloat = 62
    let rowGap: CGFloat = 40
    let contentTop = page.maxY - 116
    let blockHeight = boxSide * 3 + rowGap * 2
    let firstRowY = page.minY + (contentTop - page.minY - blockHeight) / 2 + blockHeight - boxSide
    let boxX = page.minX + 58
    let lineX = boxX + boxSide + 34
    let lineRight = page.maxX - 58

    for index in 0..<3 {
        let y = firstRowY - CGFloat(index) * (boxSide + rowGap)
        let box = CGRect(x: boxX, y: y, width: boxSide, height: boxSide)
        let boxPath = CGPath(roundedRect: box, cornerWidth: 18, cornerHeight: 18, transform: nil)

        if index == 0 {
            ctx.addPath(boxPath)
            ctx.setFillColor(ink)
            ctx.fillPath()

            ctx.saveGState()
            ctx.setStrokeColor(paper)
            ctx.setLineWidth(9)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: box.minX + boxSide * 0.24, y: box.minY + boxSide * 0.52))
            ctx.addLine(to: CGPoint(x: box.minX + boxSide * 0.43, y: box.minY + boxSide * 0.31))
            ctx.addLine(to: CGPoint(x: box.minX + boxSide * 0.78, y: box.minY + boxSide * 0.69))
            ctx.strokePath()
            ctx.restoreGState()
        } else {
            ctx.addPath(boxPath)
            ctx.setStrokeColor(color(0x33_41_7E, alpha: 0.30))
            ctx.setLineWidth(8)
            ctx.strokePath()
        }

        let lineHeight: CGFloat = 24
        let lineRect = CGRect(x: lineX, y: y + (boxSide - lineHeight) / 2,
                              width: (index == 2 ? lineRight - 96 : lineRight) - lineX,
                              height: lineHeight)
        ctx.addPath(CGPath(roundedRect: lineRect, cornerWidth: 12, cornerHeight: 12, transform: nil))
        ctx.setFillColor(index == 0 ? color(0xC9_CE_E4, alpha: 0.75) : line)
        ctx.fillPath()
    }
}

func renderMaster() -> CGImage {
    let ctx = makeContext(size: canvas)
    drawIcon(in: ctx)
    guard let image = ctx.makeImage() else { fatalError("Не удалось отрисовать иконку") }
    return image
}

func resize(_ image: CGImage, to size: CGFloat) -> CGImage {
    let ctx = makeContext(size: size)
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let resized = ctx.makeImage() else { fatalError("Не удалось смасштабировать до \(size)") }
    return resized
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        fatalError("Не удалось создать файл \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Не удалось записать \(url.path)")
    }
}

// MARK: - Раскладка по размерам

struct Slot {
    let filename: String
    let pixels: CGFloat
    let json: String
}

let macSizes: [(point: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
    (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]

var slots: [Slot] = macSizes.map { point, scale in
    let suffix = scale == 1 ? "" : "@\(scale)x"
    let name = "icon_\(point)x\(point)\(suffix).png"
    let json = """
        {
              "filename" : "\(name)",
              "idiom" : "mac",
              "scale" : "\(scale)x",
              "size" : "\(point)x\(point)"
            }
    """.trimmingCharacters(in: .whitespacesAndNewlines)
    return Slot(filename: name, pixels: CGFloat(point * scale), json: json)
}

// Один слот для iOS: с Xcode 14 хватает единственного изображения 1024x1024.
slots.append(Slot(
    filename: "icon_ios_1024.png",
    pixels: 1024,
    json: """
    {
          "filename" : "icon_ios_1024.png",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        }
    """.trimmingCharacters(in: .whitespacesAndNewlines)
))

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconSet = repoRoot
    .appendingPathComponent("App/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try? FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)

let master = renderMaster()
for slot in slots {
    let image = slot.pixels == canvas ? master : resize(master, to: slot.pixels)
    writePNG(image, to: iconSet.appendingPathComponent(slot.filename))
    print("  \(slot.filename) — \(Int(slot.pixels))px")
}

let contents = """
{
  "images" : [
    \(slots.map(\.json).joined(separator: ",\n    "))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""
try contents.write(to: iconSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Иконка обновлена: \(iconSet.path)")
