import Foundation

/// Версия приложения для сравнения установленной сборки с последним релизом.
///
/// Разбирает и `1.2.3`, и тег релиза `v1.2.3`, и версию-заглушку ручной сборки
/// `0.0.0-1a2b3c4`. Сравнение — по числам слева направо, а не по строке:
/// строковое сравнение считает, что `1.10.0` старше `1.9.0`.
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    /// Числовые части версии: `[1, 2, 3]` для `1.2.3`.
    public let numbers: [Int]
    /// Суффикс после дефиса (`beta`, хеш коммита) — признак промежуточной сборки.
    public let prerelease: String?

    /// Разбирает строку версии. Возвращает `nil`, если числовой части нет:
    /// на непонятной версии лучше промолчать, чем звать обновляться наугад.
    public init?(_ text: String) {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") { value.removeFirst() }

        // Метаданные сборки (`+build`) на порядок версий не влияют — отбрасываем.
        if let plus = value.firstIndex(of: "+") { value = String(value[..<plus]) }

        let suffix: String?
        if let dash = value.firstIndex(of: "-") {
            suffix = String(value[value.index(after: dash)...])
            value = String(value[..<dash])
        } else {
            suffix = nil
        }

        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }

        var numbers: [Int] = []
        for part in parts {
            guard let number = Int(part), number >= 0 else { return nil }
            numbers.append(number)
        }

        self.numbers = numbers
        self.prerelease = (suffix?.isEmpty ?? true) ? nil : suffix
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        // Недостающие части считаем нулями: 1.2 и 1.2.0 — одна и та же версия.
        let count = max(lhs.numbers.count, rhs.numbers.count)
        for index in 0..<count {
            let left = index < lhs.numbers.count ? lhs.numbers[index] : 0
            let right = index < rhs.numbers.count ? rhs.numbers[index] : 0
            if left != right { return left < right }
        }

        // Числа равны: промежуточная сборка старше готового релиза с тем же
        // номером, иначе установленная 1.1.0-beta не увидела бы релиз 1.1.0.
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil): return false
        case (nil, _?): return false
        case (_?, nil): return true
        case let (left?, right?): return left < right
        }
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public func hash(into hasher: inout Hasher) {
        // Хеш согласован с `==`: хвостовые нули не меняют версию.
        var numbers = self.numbers
        while numbers.count > 1 && numbers.last == 0 { numbers.removeLast() }
        hasher.combine(numbers)
        hasher.combine(prerelease)
    }

    public var description: String {
        let base = numbers.map(String.init).joined(separator: ".")
        return prerelease.map { "\(base)-\($0)" } ?? base
    }

    /// Стоит ли предлагать обновление: обе версии разобрались и релиз новее.
    ///
    /// Более новая установленная сборка (собранная локально из свежего кода)
    /// баннер не показывает.
    public static func isUpdateAvailable(installed: String, latest: String) -> Bool {
        guard let installed = AppVersion(installed), let latest = AppVersion(latest) else {
            return false
        }
        return installed < latest
    }
}
