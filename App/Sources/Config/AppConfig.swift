import Foundation

/// Хранит настройки подключения к Supabase (URL проекта и anon-ключ).
/// Значения сохраняются в UserDefaults; их можно задать на экране настроек
/// или через переменные окружения при сборке.
struct AppConfig: Equatable {
    var supabaseURL: String
    var supabaseAnonKey: String

    var isConfigured: Bool {
        guard let url = normalizedURL else { return false }
        _ = url
        return !supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Ключ без случайных пробелов/переводов строк.
    var normalizedKey: String {
        supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Базовый URL проекта: убираем пробелы, хвостовые слэши и путь `/rest/v1`
    /// или `/auth/v1`, если пользователь скопировал адрес эндпоинта целиком.
    var normalizedURL: URL? {
        var text = supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "https://" + text
        }

        // Отрезаем известные пути эндпоинтов и хвостовые слэши.
        for suffix in ["/rest/v1", "/auth/v1", "/storage/v1", "/realtime/v1"] {
            if let range = text.range(of: suffix, options: [.caseInsensitive]) {
                text = String(text[..<range.lowerBound])
            }
        }
        while text.hasSuffix("/") { text.removeLast() }

        guard let url = URL(string: text), let host = url.host, host.contains(".") else {
            return nil
        }
        return url
    }

    static let empty = AppConfig(supabaseURL: "", supabaseAnonKey: "")
}

enum AppConfigStore {
    private static let urlKey = "supabase_url"
    private static let keyKey = "supabase_anon_key"

    static func load() -> AppConfig {
        let defaults = UserDefaults.standard
        let envURL = ProcessInfo.processInfo.environment["SUPABASE_URL"]
        let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
        return AppConfig(
            supabaseURL: envURL ?? defaults.string(forKey: urlKey) ?? "",
            supabaseAnonKey: envKey ?? defaults.string(forKey: keyKey) ?? ""
        )
    }

    static func save(_ config: AppConfig) {
        let defaults = UserDefaults.standard
        defaults.set(config.supabaseURL, forKey: urlKey)
        defaults.set(config.supabaseAnonKey, forKey: keyKey)
    }
}
