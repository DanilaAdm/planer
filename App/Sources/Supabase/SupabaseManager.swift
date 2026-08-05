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

    private(set) var client: SupabaseClient?

    // MARK: - Конфигурация

    func configure(with config: AppConfig) {
        lastErrorMessage = nil
        guard config.isConfigured, let url = config.normalizedURL else {
            client = nil
            authState = .unconfigured
            return
        }

        let options = SupabaseClientOptions(
            db: SupabaseClientOptions.DatabaseOptions(
                encoder: PlannerCoding.makeEncoder(),
                decoder: PlannerCoding.makeDecoder()
            )
        )
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: config.normalizedKey,
            options: options
        )
        Task { await refreshSession() }
    }

    /// Создать RemoteStore для текущего клиента (nil, если не настроен).
    func makeRemoteStore() -> SupabaseRemoteStore? {
        guard let client else { return nil }
        return SupabaseRemoteStore(client: client)
    }

    // MARK: - Аутентификация

    func refreshSession() async {
        guard let client else {
            authState = .unconfigured
            return
        }
        do {
            let session = try await client.auth.session
            authState = .signedIn(email: session.user.email ?? "—")
        } catch {
            authState = .signedOut
        }
    }

    func signIn(email: String, password: String) async {
        guard let client else { return }
        lastErrorMessage = nil
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            authState = .signedIn(email: session.user.email ?? email)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = readable(error)
        }
    }

    func signUp(email: String, password: String) async {
        guard let client else { return }
        lastErrorMessage = nil
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if response.session != nil {
                authState = .signedIn(email: email)
            } else {
                lastErrorMessage = "Проверьте почту для подтверждения регистрации, затем войдите."
            }
        } catch {
            lastErrorMessage = readable(error)
        }
    }

    func signOut() async {
        if let client {
            try? await client.auth.signOut()
        }
        authState = .signedOut
    }

    /// Войти в демо-режим (без Supabase): показать интерфейс на примерных данных.
    func signInDemo() {
        lastErrorMessage = nil
        authState = .signedIn(email: "Демо-режим")
    }

    private func readable(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    #if DEBUG
    /// Принудительно перевести в состояние «вошёл» (используется в UI-тестах).
    func forceSignedIn(email: String) {
        authState = .signedIn(email: email)
    }
    #endif
}
