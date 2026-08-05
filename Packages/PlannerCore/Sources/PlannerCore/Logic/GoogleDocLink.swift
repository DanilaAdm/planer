import Foundation

/// Разбор ссылки на документ Google и построение адресов для чтения.
///
/// Ссылка вида `/edit` открывает полноценный редактор Google: он тяжёлый и
/// требует входа в аккаунт, а вход внутри WKWebView Google блокирует. Поэтому
/// для просмотра внутри приложения используются облегчённые адреса:
/// `mobilebasic` для документов (текст с переносом строк) и `htmlview` для таблиц.
public struct GoogleDocLink: Equatable, Hashable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        case document
        case spreadsheet
        case presentation
        /// Прочие сервисы docs.google.com (формы, рисунки) — режима чтения нет.
        case other
    }

    public let documentId: String
    public let kind: Kind
    /// Идентификатор таба документа из `?tab=t.0`, если он был в ссылке.
    public let tab: String?
    public let original: URL

    /// Якорь исходной ссылки (например `#gid=0` у таблиц) — переносим в адрес чтения.
    private let fragment: String?

    /// Разобрать ссылку на docs.google.com. Возвращает nil для любых других адресов
    /// и для опубликованных документов (`/d/e/<id>/pub`), у которых нет режима чтения:
    /// такие ссылки открываются как есть.
    public init?(_ url: URL) {
        guard let host = url.host?.lowercased(),
              host == "docs.google.com" || host == "www.docs.google.com" else { return nil }

        var parts = url.pathComponents.filter { $0 != "/" }

        // Ссылки вида /document/u/0/d/<id>/edit содержат номер аккаунта — он не нужен.
        if let accountIndex = parts.firstIndex(of: "u"),
           accountIndex + 1 < parts.count,
           Int(parts[accountIndex + 1]) != nil {
            parts.removeSubrange(accountIndex...(accountIndex + 1))
        }

        guard let service = parts.first,
              let idIndex = parts.firstIndex(of: "d"),
              idIndex + 1 < parts.count else { return nil }

        let identifier = parts[idIndex + 1]
        guard !identifier.isEmpty, identifier != "e" else { return nil }

        self.documentId = identifier
        self.kind = Kind(service: service)
        self.tab = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "tab" }?
            .value
        self.fragment = url.fragment
        self.original = url
    }

    /// Облегчённый адрес для чтения внутри приложения.
    public var readerURL: URL {
        switch kind {
        case .document: return address(suffix: "mobilebasic")
        case .spreadsheet: return address(suffix: "htmlview")
        case .presentation: return address(suffix: "preview")
        case .other: return original
        }
    }

    /// Адрес с оригинальной вёрсткой Google Docs (кнопка «Полная версия»).
    public var fullViewURL: URL {
        kind == .other ? original : address(suffix: "preview")
    }

    /// Адрес для открытия во внешнем браузере — исходная ссылка с возможностью правки.
    public var browserURL: URL { original }

    /// Адрес для чтения любой ссылки: для документов Google — облегчённый,
    /// для остальных — сама ссылка.
    public static func readerURL(for url: URL) -> URL {
        GoogleDocLink(url)?.readerURL ?? url
    }

    /// Привести введённую вручную ссылку к пригодному для загрузки URL:
    /// убрать пробелы и подставить `https://`, если схему не скопировали.
    public static func normalized(_ text: String) -> URL? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let lowercased = value.lowercased()
        if !lowercased.hasPrefix("https://") && !lowercased.hasPrefix("http://") {
            // Чужую схему (mailto:, ftp: и т.п.) не подменяем — такая ссылка не подходит.
            guard !hasScheme(value) else { return nil }
            value = "https://" + value
        }

        guard let url = URL(string: value),
              let host = url.host,
              host.contains(".") else { return nil }
        return url
    }

    /// Начинается ли строка с собственной схемы (`mailto:`, `ftp://`).
    /// Двоеточие перед номером порта (`docs.google.com:8443/…`) схемой не считается.
    private static func hasScheme(_ text: String) -> Bool {
        let head = text.prefix { $0 != "/" }
        guard let colon = head.firstIndex(of: ":") else { return false }

        let scheme = head[head.startIndex..<colon]
        guard let first = scheme.first, first.isLetter else { return false }
        guard scheme.dropFirst().allSatisfy({ $0.isLetter || $0.isNumber || "+-.".contains($0) }) else {
            return false
        }

        let rest = head[head.index(after: colon)...]
        return rest.isEmpty || !rest.allSatisfy(\.isNumber)
    }

    private func address(suffix: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "docs.google.com"
        components.path = "/\(kind.service)/d/\(documentId)/\(suffix)"
        if let tab {
            components.queryItems = [URLQueryItem(name: "tab", value: tab)]
        }
        components.fragment = fragment
        return components.url ?? original
    }
}

private extension GoogleDocLink.Kind {
    init(service: String) {
        switch service {
        case "document": self = .document
        case "spreadsheets": self = .spreadsheet
        case "presentation": self = .presentation
        default: self = .other
        }
    }

    /// Первый компонент пути в адресах Google для этого типа документа.
    var service: String {
        switch self {
        case .document: return "document"
        case .spreadsheet: return "spreadsheets"
        case .presentation: return "presentation"
        case .other: return ""
        }
    }
}
