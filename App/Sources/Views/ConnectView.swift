import SwiftUI

/// Экран первичной настройки подключения к Supabase и входа/регистрации.
struct ConnectView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @EnvironmentObject private var env: AppEnvironment

    @State private var config = AppConfigStore.load()
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var isBusy = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header

                demoBox

                SectionCard(title: "Подключение к Supabase (PostgreSQL)") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        LabeledField(title: "Project URL", text: $config.supabaseURL,
                                     placeholder: "https://xxxx.supabase.co")
                        LabeledField(title: "Anon-ключ", text: $config.supabaseAnonKey,
                                     placeholder: "eyJhbGci...", secure: true)
                        Button("Сохранить и подключиться") {
                            AppConfigStore.save(config)
                            supabase.configure(with: config)
                        }
                        .buttonStyle(.primaryFilled)
                        .disabled(!config.isConfigured)
                    }
                }

                if supabase.authState != .unconfigured {
                    authBox
                }

                if let message = supabase.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.destructive)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
        .tint(Theme.accent)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text("Планер репетитора")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.ink)
            Text("Календарь занятий, ученики и учёт оплат")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.xs)
    }

    private var demoBox: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Хотите просто посмотреть приложение? Войдите в демо-режим — откроется планер-дневник с примерными учениками, уроками и задачами. Supabase не требуется.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                Button {
                    Task { await DemoMode.enter(env: env, supabase: supabase) }
                } label: {
                    Label("Посмотреть демо (без Supabase)", systemImage: "eye")
                }
                .buttonStyle(.primaryFilled)
                .accessibilityIdentifier("demoModeButton")
            }
        }
    }

    private var authBox: some View {
        SectionCard(title: isRegistering ? "Регистрация" : "Вход") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                LabeledField(title: "E-mail", text: $email, placeholder: "you@example.com")
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                #endif
                LabeledField(title: "Пароль", text: $password, placeholder: "Минимум 6 символов", secure: true)

                Button {
                    Task { await authenticate() }
                } label: {
                    HStack {
                        if isBusy { ProgressView().controlSize(.small) }
                        Text(isRegistering ? "Зарегистрироваться" : "Войти")
                    }
                }
                .buttonStyle(.primaryFilled)
                .disabled(isBusy || email.isEmpty || password.isEmpty)

                Button(isRegistering ? "У меня уже есть аккаунт" : "Создать аккаунт") {
                    isRegistering.toggle()
                }
                .font(.footnote)
                .tint(Theme.accent)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func authenticate() async {
        isBusy = true
        defer { isBusy = false }
        if isRegistering {
            await supabase.signUp(email: email, password: password)
        } else {
            await supabase.signIn(email: email, password: password)
        }
    }
}

/// Поле ввода с подписью, поддерживает защищённый ввод.
struct LabeledField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var secure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            if secure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
            }
        }
    }
}
