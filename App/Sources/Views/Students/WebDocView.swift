import SwiftUI
import WebKit
import PlannerCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Оформление документа

/// CSS, который приводит облегчённую версию Google-документа (`mobilebasic`)
/// к читаемому виду: убирает служебный интерфейс Google, растягивает текст
/// на всю ширину и поддерживает тёмную тему.
enum DocReaderStyle {
    static let css = """
    .docs-ml-header, .docs-ml-promotion { display: none !important; }
    .app-container {
        margin-top: 0 !important;
        height: 100% !important;
        overflow: auto !important;
        -webkit-overflow-scrolling: touch;
    }
    html, body { margin: 0 !important; -webkit-text-size-adjust: 100%; }
    .doc, .doc-container { padding: 0 !important; }
    .doc .doc-content {
        max-width: none !important;
        padding: 16px 18px 32px 18px !important;
        box-sizing: border-box !important;
        width: 100% !important;
    }
    .doc-content, .doc-content * { line-height: 1.5 !important; }
    /* Таблицы и картинки не должны вылезать за край экрана. */
    img, table { max-width: 100% !important; height: auto !important; }
    table { table-layout: auto !important; word-break: break-word !important; }
    @media (prefers-color-scheme: dark) {
        html, body, .doc, .doc-container, .doc-content { background: #1C1C1E !important; }
        .doc-content, .doc-content * { color: #F2F2F7 !important; }
        a, a * { color: #6FA8FF !important; }
        td, th { border-color: #48484A !important; }
    }
    """

    /// Скрипт вставляет стиль после разбора страницы. Правила продолжают
    /// действовать и для элементов, которые Google дорисовывает скриптами позже.
    static var userScript: WKUserScript {
        let source = """
        (function() {
            var style = document.createElement('style');
            style.textContent = `\(css)`;
            document.head.appendChild(style);
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
}

// MARK: - Состояние просмотрщика

/// Владеет `WKWebView`, следит за загрузкой документа и обрабатывает навигацию.
///
/// Методы делегатов WebKit вызываются на главном потоке, поэтому состояние
/// меняется в них напрямую.
final class DocReaderModel: NSObject, ObservableObject {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    /// Режим отображения: облегчённый для чтения или оригинальная вёрстка Google.
    enum Mode: Equatable {
        case reader
        case full
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var progress: Double = 0
    @Published private(set) var documentTitle: String?
    @Published private(set) var mode: Mode = .reader

    let webView: WKWebView
    /// Исходная ссылка ученика — её открываем во внешнем браузере.
    let browserURL: URL

    private let readerURL: URL
    private let fullURL: URL
    private var progressObservation: NSKeyValueObservation?

    init(url: URL) {
        let link = GoogleDocLink(url)
        self.browserURL = link?.browserURL ?? url
        self.readerURL = link?.readerURL ?? url
        self.fullURL = link?.fullViewURL ?? url

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController.addUserScript(DocReaderStyle.userScript)
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        #endif
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        #if os(iOS)
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.accessibilityIdentifier = "docWebView"
        #elseif os(macOS)
        webView.setAccessibilityIdentifier("docWebView")
        #endif

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            let value = webView.estimatedProgress
            DispatchQueue.main.async { self?.progress = value }
        }
    }

    deinit {
        progressObservation?.invalidate()
    }

    /// Есть ли смысл предлагать «Полную версию» — у не-Google ссылок она совпадает с чтением.
    var canSwitchToFullVersion: Bool { fullURL != readerURL }

    func loadIfNeeded() {
        guard webView.url == nil else { return }
        load(mode)
    }

    func load(_ mode: Mode) {
        self.mode = mode
        phase = .loading
        progress = 0
        webView.load(URLRequest(url: mode == .reader ? readerURL : fullURL))
    }

    func reload() {
        load(mode)
    }

    func applyZoom(_ zoom: CGFloat) {
        webView.pageZoom = zoom
    }

    func openInBrowser() {
        DocReaderModel.openExternally(browserURL)
    }

    static func openExternally(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Сообщение о проблемах со связью. По нему UI-тест отличает «нет сети»
    /// от «документ закрыт настройками доступа».
    static let connectivityMessage = "Нет связи с интернетом. Проверьте подключение и попробуйте снова."

    static func message(forStatusCode code: Int) -> String {
        switch code {
        case 401, 403:
            return "Документ закрыт настройками доступа. Откройте доступ по ссылке в Google Docs."
        case 404:
            return "Документ не найден — возможно, ссылка изменилась."
        default:
            return "Google вернул ошибку \(code)."
        }
    }
}

// MARK: - Навигация

extension DocReaderModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        // Мобильная версия Google пытается уйти в приложение Google Docs
        // (googledocs://, intent://) — такие переходы гасим.
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            decisionHandler(.cancel)
            return
        }

        let host = url.host?.lowercased() ?? ""

        // Вход в аккаунт Google внутри WKWebView заблокирован самим Google,
        // поэтому такой документ открывается только во внешнем браузере.
        if host == "accounts.google.com" {
            decisionHandler(.cancel)
            phase = .failed("Google просит войти в аккаунт. Откройте документ в браузере или включите доступ по ссылке.")
            return
        }

        // Ссылки из текста документа уводят на сторонние сайты — им место в браузере.
        if navigationAction.navigationType == .linkActivated, !host.hasSuffix("google.com") {
            decisionHandler(.cancel)
            DocReaderModel.openExternally(url)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame,
              let response = navigationResponse.response as? HTTPURLResponse,
              response.statusCode >= 400 else {
            decisionHandler(.allow)
            return
        }

        decisionHandler(.cancel)
        phase = .failed(DocReaderModel.message(forStatusCode: response.statusCode))
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        phase = .loading
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        phase = .loaded
        let title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        documentTitle = (title?.isEmpty == false) ? title : nil

        #if os(iOS)
        // WKWebView on iOS exposes only the page title to XCUITest, unlike macOS,
        // where individual text nodes are accessible. Preserve the real page
        // text as the web view's accessibility value for VoiceOver and UI tests.
        webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { result, _ in
            guard let text = result as? String else { return }
            webView.accessibilityValue = String(text.prefix(20_000))
        }
        #endif
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handle(error)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        handle(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reload()
    }

    private func handle(_ error: Error) {
        let nsError = error as NSError
        // Отменённая загрузка — не ошибка: так выглядит переход по новой ссылке.
        guard nsError.domain != NSURLErrorDomain || nsError.code != NSURLErrorCancelled else { return }

        switch nsError.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
            phase = .failed(DocReaderModel.connectivityMessage)
        case NSURLErrorTimedOut:
            phase = .failed("Google не ответил вовремя. Попробуйте ещё раз.")
        default:
            phase = .failed(nsError.localizedDescription)
        }
    }
}

extension DocReaderModel: WKUIDelegate {
    /// Ссылки с `target="_blank"` открываем в этом же вебвью, иначе они теряются.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

// MARK: - Экран документа

/// Просмотр Google-документа ученика внутри приложения.
struct DocReaderView: View {
    private let fallbackTitle: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: DocReaderModel
    @AppStorage("docReaderZoom") private var zoom: Double = 1

    private static let zoomRange: ClosedRange<Double> = 0.7...2.5
    private static let zoomStep: Double = 0.15

    init(url: URL, fallbackTitle: String = "Документ") {
        self.fallbackTitle = fallbackTitle
        _model = StateObject(wrappedValue: DocReaderModel(url: url))
    }

    var body: some View {
        // Своя панель управления вместо тулбара: в листе на macOS SwiftUI
        // показывает лишь часть элементов тулбара, а здесь вид одинаков на обеих платформах.
        VStack(spacing: 0) {
            controlBar
            Divider()
            documentArea
        }
        .background(Theme.background)
        .tint(Theme.accent)
        #if os(macOS)
        .frame(minWidth: 860, idealWidth: 980, minHeight: 680, idealHeight: 800)
        #endif
        .onAppear {
            model.applyZoom(zoom)
            model.loadIfNeeded()
        }
        .onChange(of: zoom) { _, newValue in
            model.applyZoom(newValue)
        }
    }

    private var documentArea: some View {
        ZStack {
            DocWebView(webView: model.webView)
                .opacity(isFailed ? 0 : 1)

            if case .failed(let message) = model.phase {
                errorState(message)
            } else if model.phase == .loading {
                loadingState
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button("Закрыть") { dismiss() }
                .buttonStyle(.plain)
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("docCloseButton")

            Spacer(minLength: Theme.Spacing.sm)

            Text(model.documentTitle ?? fallbackTitle)
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: Theme.Spacing.sm)

            iconButton("textformat.size.smaller", label: "Мельче", id: "docZoomOutButton") {
                zoom = max(Self.zoomRange.lowerBound, zoom - Self.zoomStep)
            }
            .disabled(zoom <= Self.zoomRange.lowerBound)

            iconButton("textformat.size.larger", label: "Крупнее", id: "docZoomInButton") {
                zoom = min(Self.zoomRange.upperBound, zoom + Self.zoomStep)
            }
            .disabled(zoom >= Self.zoomRange.upperBound)

            moreMenu
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.surface)
    }

    private func iconButton(_ systemImage: String,
                            label: String,
                            id: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private var moreMenu: some View {
        Menu {
            Button {
                model.reload()
            } label: {
                Label("Обновить", systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("docReloadButton")

            if model.canSwitchToFullVersion {
                Button {
                    model.load(model.mode == .reader ? .full : .reader)
                } label: {
                    Label(
                        model.mode == .reader ? "Полная версия" : "Режим чтения",
                        systemImage: model.mode == .reader ? "doc.richtext" : "text.alignleft"
                    )
                }
                .accessibilityIdentifier("docModeButton")
            }

            Button {
                model.openInBrowser()
            } label: {
                Label("Открыть в браузере", systemImage: "safari")
            }
            .accessibilityIdentifier("docBrowserMenuButton")
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(Theme.accent)
        .accessibilityLabel("Ещё")
        .accessibilityIdentifier("docMoreMenu")
    }

    private var isFailed: Bool {
        if case .failed = model.phase { return true }
        return false
    }

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView(value: max(model.progress, 0.05))
                .progressViewStyle(.linear)
                .frame(maxWidth: 240)
            Text("Загружаем документ…")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(Theme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface)
        )
        .accessibilityIdentifier("docLoadingIndicator")
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            EmptyStateBlock(
                title: "Документ не открылся",
                systemImage: "doc.questionmark",
                message: message
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("docErrorMessage")

            VStack(spacing: Theme.Spacing.sm) {
                Button("Повторить") { model.reload() }
                    .buttonStyle(.primaryFilled)
                    .accessibilityIdentifier("docRetryButton")
                Button("Открыть в браузере") { model.openInBrowser() }
                    .buttonStyle(.secondarySoft)
                    .accessibilityIdentifier("docOpenInBrowserButton")
            }
            .frame(maxWidth: 320)
        }
        .padding(Theme.Spacing.lg)
        .centeredContent(maxWidth: 480)
    }

}

// MARK: - Обёртка WKWebView

#if os(iOS)
/// Обёртка WKWebView для iOS.
struct DocWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#elseif os(macOS)
/// Обёртка WKWebView для macOS.
struct DocWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#endif
