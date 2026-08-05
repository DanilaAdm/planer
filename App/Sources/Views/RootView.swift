import SwiftUI
#if os(macOS)
import AppKit
#endif

struct RootView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @EnvironmentObject private var env: AppEnvironment

    private var isSignedIn: Bool {
        if case .signedIn = supabase.authState { return true }
        return false
    }

    var body: some View {
        Group {
            switch supabase.authState {
            case .signedIn:
                MainTabView()
            case .signedOut, .unconfigured:
                ConnectView()
            }
        }
        #if os(macOS)
        .background(WindowChrome(titlebarColor: isSignedIn ? Theme.topBarTop : nil))
        #endif
        .onChange(of: supabase.authState) { _, newValue in
            handleAuthChange(newValue)
        }
    }

    private func handleAuthChange(_ state: SupabaseManager.AuthState) {
        if case .signedIn = state {
            if !env.testMode {
                env.setRemoteStore(supabase.makeRemoteStore())
            }
            Task {
                await env.reloadStudents()
                await env.loadLessons(for: env.selectedDate, scope: .week)
            }
        } else {
            // Выход (в т.ч. из демо-режима): сбрасываем состояние, чтобы можно было
            // подключить реальный Supabase.
            env.testMode = false
            env.setRemoteStore(nil)
        }
    }
}

// MARK: - Разделы приложения

enum AppTab: String, CaseIterable, Identifiable {
    case calendar = "Календарь"
    case students = "Ученики"
    case earnings = "Заработок"
    case settings = "Настройки"

    var id: String { rawValue }
    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .calendar: return "calendar"
        case .students: return "person.2"
        case .earnings: return "rublesign.circle"
        case .settings: return "gearshape"
        }
    }
}

private struct MainTabView: View {
    var body: some View {
        #if os(macOS)
        DesktopShell()
        #else
        MobileTabView()
        #endif
    }
}

#if os(macOS)

/// Красит заголовок окна в цвет шапки приложения.
///
/// По умолчанию в macOS заголовок — полупрозрачное «стекло»: он подхватывает то,
/// что видно за окном, и над светлой шапкой появляется чужеродная тёмная полоса.
/// Непрозрачный заголовок в цвете `titlebarColor` соединяет его с панелью
/// разделов в одну полосу. `nil` возвращает системное оформление.
private struct WindowChrome: NSViewRepresentable {
    let titlebarColor: Color?

    func makeCoordinator() -> WindowChromeCoordinator { WindowChromeCoordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView()
        attach(view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        attach(nsView, coordinator: context.coordinator)
    }

    private func attach(_ view: NSView, coordinator: WindowChromeCoordinator) {
        coordinator.titlebarColor = titlebarColor
        // На момент создания представление ещё не привязано к окну.
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            coordinator.attach(to: window)
        }
    }
}

/// Представление живёт под всем содержимым окна и нужно только ради доступа к
/// `NSWindow`. Обычный `NSView` перехватывал бы клики по всему окну, поэтому он
/// полностью исключён из поиска цели для мыши.
private final class PassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Следит за окном и восстанавливает оформление: SwiftUI возвращает заголовок
/// окна каждый раз, когда `navigationTitle` активного раздела меняется.
private final class WindowChromeCoordinator {
    var titlebarColor: Color? {
        didSet { apply() }
    }

    private weak var window: NSWindow?
    private var observer: NSObjectProtocol?

    func attach(to window: NSWindow) {
        if self.window !== window {
            removeObserver()
            self.window = window
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didUpdateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in self?.apply() }
        }
        apply()
    }

    /// Значения выставляются только при реальном отличии: уведомление об
    /// обновлении окна приходит на каждом цикле событий.
    private func apply() {
        guard let window else { return }
        let transparent = titlebarColor != nil
        let background = titlebarColor.map(NSColor.init) ?? .windowBackgroundColor

        if window.titlebarAppearsTransparent != transparent {
            window.titlebarAppearsTransparent = transparent
        }
        if window.backgroundColor != background {
            window.backgroundColor = background
        }
    }

    private func removeObserver() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    deinit { removeObserver() }
}

/// Оболочка окна на macOS.
///
/// Системный `TabView` показывает разделы прямо в заголовке окна и рисует
/// выбранный тёмной «пилюлей», которая выпадает из тёплой палитры приложения.
/// Поэтому переключатель разделов собран вручную: тёплая подложка и оранжевый
/// индикатор выбранного раздела.
private struct DesktopShell: View {
    @State private var selection: AppTab = .calendar

    var body: some View {
        VStack(spacing: 0) {
            AppTopTabBar(selection: $selection)
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selection {
        case .calendar: CalendarRootView()
        case .students: StudentsListView()
        case .earnings: EarningsView()
        case .settings: SettingsView()
        }
    }
}

private struct AppTopTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                TabPill(tab: tab, isSelected: tab == selection, indicator: indicator) {
                    guard tab != selection else { return }
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        selection = tab
                    }
                }
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.75), lineWidth: Theme.Stroke.hairline)
                .allowsHitTesting(false)
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(Theme.topBarGradient)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.brandDeep.opacity(0.16))
                .frame(height: Theme.Stroke.hairline)
                .allowsHitTesting(false)
        }
    }
}

private struct TabPill: View {
    let tab: AppTab
    let isSelected: Bool
    let indicator: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Theme.brandGradient)
                        .shadow(color: Theme.brand.opacity(0.35), radius: 5, y: 2)
                        .matchedGeometryEffect(id: "selectedTab", in: indicator)
                } else if isHovering {
                    Capsule(style: .continuous)
                        .fill(Theme.brand.opacity(0.14))
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var foreground: Color {
        if isSelected { return .white }
        return Theme.ink.opacity(isHovering ? 0.95 : 0.68)
    }
}

#else

private struct MobileTabView: View {
    var body: some View {
        TabView {
            CalendarRootView()
                .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage) }

            StudentsListView()
                .tabItem { Label(AppTab.students.title, systemImage: AppTab.students.systemImage) }

            EarningsView()
                .tabItem { Label(AppTab.earnings.title, systemImage: AppTab.earnings.systemImage) }

            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
        }
        .tint(Theme.brand)
    }
}

#endif
