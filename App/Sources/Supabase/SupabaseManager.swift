import Foundation
import PlannerCore
import Supabase

/// Управляет клиентом Supabase и состоянием аутентификации.
@MainActor
final class SupabaseManager: ObservableObject {
    enum AuthState: Equatable {
        case unconfigured
        case signedOut
        case signedIn(email: String)
    }

    @Published private(set) var authState: AuthState = .unconfigured
    @Published var lastErrorMessage: String?

    /// Идентификатор вошедшего пользователя. По нему локальный кэш привязывается
    /// к аккаунту, чтобы данные одного пользователя не показывались другому.
    @Published private(set) var currentUserId: UUID?

    private(set) var client: SupabaseClient?
    private var authObservation: Task<Void, Never>?

    // MARK: - Конфигурация

    func configure(with config: AppConfig) {
        lastErrorMessage = nil
        authObservation?.cancel()
        authObservation = nil

        guard config.isConfigured, let url = config.normalizedURL else {
            client = nil
            currentUserId = nil
            authState = .unconfigured
            return
        }

        let options = SupabaseClientOptions(
            db: SupabaseClientOptions.DatabaseOptions(
                encoder: PlannerCoding.makeEncoder(),
                decoder: PlannerCoding.makeDecoder()
            )
        )
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: config.normalizedKey,
            options: options
        )
        self.client = client

        // Сессия читается из Keychain синхронно и без обращения к сети, поэтому
        // приложение открывается под тем же аккаунтом даже полностью офлайн.
        // Просроченный токен здесь не помеха: SDK обновит его сам, когда связь
        // появится, и пришлёт событие `.tokenRefreshed`.
        apply(session: client.auth.currentSession)
        observeAuthChanges(of: client)
    }

    /// Создать RemoteStore для текущего клиента (nil, если не настроен).
    func makeRemoteStore() -> SupabaseRemoteStore? {
        guard let client else { return nil }
        return SupabaseRemoteStore(client: client)
    }

    // MARK: - Аутентификация

    /// Войти по e-mail и паролю. Проверку выполняет сервер Supabase.
    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        guard let client else {
            lastErrorMessage = AuthMessage.notConfigured
            return false
        }
        lastErrorMessage = nil
        do {
            let session = try await client.auth.signIn(
                email: normalized(email),
                password: password
            )
            apply(session: session)
            return true
        } catch {
            lastErrorMessage = AuthMessage.text(for: error)
            return false
        }
    }

    /// Создать аккаунт. При выключенном подтверждении почты сразу возвращается
    /// сессия, и отдельный вход не требуется.
    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        guard let client else {
            lastErrorMessage = AuthMessage.notConfigured
            return false
        }
        lastErrorMessage = nil
        let address = normalized(email)
        do {
            let response = try await client.auth.signUp(email: address, password: password)
            if let session = response.session {
                apply(session: session)
                return true
            }
            // Сессии нет — значит в проекте включено подтверждение почты.
            lastErrorMessage = AuthMessage.confirmationRequired
            return false
        } catch {
            lastErrorMessage = AuthMessage.text(for: error)
            return false
        }
    }

    func signOut() async {
        if let client {
            try? await client.auth.signOut()
        }
        apply(session: nil)
    }

    /// Войти в демо-режим (без Supabase): показать интерфейс на примерных данных.
    func signInDemo() {
        lastErrorMessage = nil
        currentUserId = nil
        authState = .signedIn(email: "Демо-режим")
    }

    // MARK: - Состояние сессии

    /// Единая точка смены состояния: идентификатор пользователя выставляется
    /// раньше `authState`, потому что подписчики читают его в реакции на смену
    /// состояния — чтобы понять, чей кэш открывать.
    private func apply(session: Session?) {
        guard let session else {
            currentUserId = nil
            // Именно `.signedOut`, а не `.unconfigured`: клиент настроен, просто
            // никто не вошёл — форма входа должна быть доступна.
            authState = .signedOut
            return
        }
        currentUserId = session.user.id
        authState = .signedIn(email: session.user.email ?? "—")
    }

    /// Следить за сессией: автоматическое продление токена, выход на другом
    /// устройстве и отзыв сессии должны отражаться на экране без перезапуска.
    private func observeAuthChanges(of client: SupabaseClient) {
        authObservation = Task { [weak self] in
            for await (event, session) in client.auth.authStateChanges {
                guard !Task.isCancelled, let self else { return }
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                    // `.initialSession` приходит и без сессии. Состояние в этом
                    // случае не трогаем: его уже выставил `configure`.
                    if let session { self.apply(session: session) }
                case .signedOut:
                    self.apply(session: nil)
                default:
                    break
                }
            }
        }
    }

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    #if DEBUG
    /// Принудительно перевести в состояние «вошёл» (используется в UI-тестах).
    func forceSignedIn(email: String) {
        currentUserId = nil
        authState = .signedIn(email: email)
    }
    #endif
}
