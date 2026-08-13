import Foundation
import PlannerCore

/// Последний опубликованный релиз приложения.
struct ReleaseInfo: Equatable, Sendable {
    let version: AppVersion
    /// Страница релиза на GitHub — запасной вариант, если файла сборки в нём нет.
    let pageURL: URL
    /// Прямая ссылка на `.dmg` из вложений релиза.
    let downloadURL: URL?

    /// Куда вести пользователя по кнопке «Обновить»: на macOS — сразу на файл
    /// сборки, на других платформах — на страницу релиза, потому что готового
    /// файла для установки там нет.
    var updateURL: URL {
        #if os(macOS)
        return downloadURL ?? pageURL
        #else
        return pageURL
        #endif
    }
}

/// Проверяет, не вышла ли версия новее установленной.
///
/// Приложение распространяется файлом с GitHub Releases, минуя App Store,
/// поэтому система об обновлениях не сообщает: без этой проверки пользователь
/// остаётся на старой версии, пока сам не зайдёт на страницу загрузки.
///
/// Проверка полностью необязательная: любая ошибка (нет сети, лимит запросов
/// GitHub, неожиданный ответ) просто не показывает баннер и ничему не мешает.
@MainActor
final class UpdateChecker: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case failed
        case available(ReleaseInfo)
    }

    @Published private(set) var status: Status = .idle
    /// Версия, для которой пользователь закрыл баннер.
    @Published private var dismissedVersion: String?

    /// Версия установленной сборки (`CFBundleShortVersionString`).
    let installedVersion: String

    private let fetchLatest: @Sendable () async throws -> ReleaseInfo
    private let defaults: UserDefaults
    /// Между автоматическими проверками: приложение возвращается в активное
    /// состояние много раз за день, дёргать GitHub на каждый раз незачем.
    private let minimumInterval: TimeInterval
    private var lastCheckedAt: Date?
    private var isChecking = false

    private static let dismissedVersionKey = "dismissed_update_version"

    init(
        installedVersion: String = Bundle.main.marketingVersion,
        defaults: UserDefaults = .standard,
        minimumInterval: TimeInterval = 30 * 60,
        fetchLatest: @escaping @Sendable () async throws -> ReleaseInfo = GitHubReleases.latest
    ) {
        self.installedVersion = installedVersion
        self.defaults = defaults
        self.minimumInterval = minimumInterval
        self.fetchLatest = fetchLatest
        self.dismissedVersion = defaults.string(forKey: Self.dismissedVersionKey)
    }

    /// Релиз для баннера: скрывается, когда пользователь закрыл его для этой версии.
    /// В настройках доступное обновление видно и после закрытия баннера.
    var bannerRelease: ReleaseInfo? {
        guard case let .available(release) = status else { return nil }
        guard dismissedVersion != release.version.description else { return nil }
        return release
    }

    /// Проверить обновления. Автоматический вызов пропускается, если проверка
    /// уже была недавно; `force` — явное нажатие в настройках.
    func check(force: Bool = false) async {
        guard !isChecking else { return }
        if !force, let lastCheckedAt, Date().timeIntervalSince(lastCheckedAt) < minimumInterval {
            return
        }

        isChecking = true
        if force { status = .checking }
        defer { isChecking = false }

        do {
            let release = try await fetchLatest()
            lastCheckedAt = Date()
            let isNewer = AppVersion.isUpdateAvailable(
                installed: installedVersion,
                latest: release.version.description
            )
            status = isNewer ? .available(release) : .upToDate
        } catch {
            // Неудачную попытку не запоминаем: следующий вход в приложение
            // должен попробовать снова, а не ждать конца интервала.
            status = .failed
        }
    }

    /// Скрыть баннер до следующей версии.
    func dismissBanner() {
        guard case let .available(release) = status else { return }
        let version = release.version.description
        dismissedVersion = version
        defaults.set(version, forKey: Self.dismissedVersionKey)
    }
}

/// Запрос последнего релиза к API GitHub.
enum GitHubReleases {
    static let repository = "DanilaAdm/planer"

    /// Имя файла сборки во вложениях релиза — его собирает `scripts/build_dmg.sh`.
    private static let assetName = "PlannerApp-macOS.dmg"

    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/\(repository)/releases/latest"
    )!

    enum Failure: Error {
        case badResponse(Int)
        /// Тег релиза не похож на версию — сравнивать не с чем.
        case unreadableTag(String)
    }

    /// Последний релиз репозитория. Черновики и предрелизы GitHub в этот ответ
    /// не включает, поэтому дополнительно их отсеивать не нужно.
    static func latest() async throws -> ReleaseInfo {
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw Failure.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let version = AppVersion(payload.tagName) else {
            throw Failure.unreadableTag(payload.tagName)
        }

        return ReleaseInfo(
            version: version,
            pageURL: payload.htmlURL,
            downloadURL: payload.assets.first { $0.name == assetName }?.browserDownloadURL
        )
    }

    private struct Payload: Decodable {
        let tagName: String
        let htmlURL: URL
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case assets
        }

        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }
    }
}

extension Bundle {
    /// Версия для пользователя — та же строка, что подставляет релизный workflow
    /// из имени тега.
    var marketingVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Номер сборки.
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
}
