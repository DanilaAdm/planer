import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct PlannerApp: App {
    @StateObject private var supabase = SupabaseManager()
    @StateObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: CachedStudent.self, CachedLesson.self, CachedPersonalTask.self, PendingChange.self
            )
        } catch {
            // В крайнем случае используем БД в памяти, чтобы приложение запустилось.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(
                for: CachedStudent.self, CachedLesson.self, CachedPersonalTask.self, PendingChange.self,
                configurations: config
            )
        }
        self.modelContainer = container
        _env = StateObject(wrappedValue: AppEnvironment(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(supabase)
                .environmentObject(env)
                .task { await bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    // Возврат в приложение — момент, когда связь чаще всего
                    // появляется снова: пробуем дожать накопленные правки.
                    guard phase == .active else { return }
                    Task { await env.syncPending() }
                }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        #endif
    }

    private func bootstrap() async {
        #if os(macOS)
        // Палитра приложения светлая и не имеет тёмного варианта. Без явного
        // светлого оформления системные части окна (заголовок, списки, панели)
        // остаются тёмными и спорят с содержимым.
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        #endif

        #if DEBUG
        if UITestSupport.isEnabled {
            await UITestSupport.bootstrap(env: env, supabase: supabase)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            await DemoMode.enter(env: env, supabase: supabase)
            return
        }
        #endif
        let config = AppConfigStore.load()
        supabase.configure(with: config)
    }
}
