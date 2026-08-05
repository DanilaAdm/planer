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
    @State private var showsAdvanced = false
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header

                if supabase.authState == .unconfigured {
                    connectionBox
                } else {
                    authBox
                }

                demoBox

                advancedBox
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
        .tint(Theme.accent)
        .alert("Не удалось войти", isPresented: showsAlert) {
            Button("Понятно", role: .cancel) {
                alertMessage = nil
                supabase.lastErrorMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var showsAlert: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
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
                .accessibilityIdentifier(isRegistering ? "signUpButton" : "signInButton")

                Button(isRegistering ? "У меня уже есть аккаунт" : "Создать аккаунт") {
                    isRegistering.toggle()
                }
                .font(.footnote)
                .tint(Theme.accent)
                .frame(maxWidth: .infinity)

                Text("Аккаунт сохраняется на сервере: с теми же почтой и паролем вы войдёте с любого устройства, и ученики, календарь и заработок будут на месте.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var connectionBox: some View {
        SectionCard(title: "Подключение к серверу") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Не удалось прочитать адрес проекта. Проверьте настройки подключения ниже.")
                    .font(.footnote)
                    .foregroundStyle(Theme.destructive)
                Button("Подключиться заново") {
                    supabase.configure(with: AppConfigStore.load())
                }
                .buttonStyle(.primaryFilled)
            }
        }
    }

    /// Адрес проекта и ключ зашиты в приложение, поэтому обычному пользователю
    /// этот раздел не нужен — он спрятан и нужен только для отладки.
    private var advancedBox: some View {
        DisclosureGroup(isExpanded: $showsAdvanced) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                LabeledField(title: "Project URL", text: $config.supabaseURL,
                             placeholder: "https://xxxx.supabase.co")
                LabeledField(title: "Ключ доступа", text: $config.supabaseAnonKey,
                             placeholder: "sb_publishable_...", secure: true)
                Button("Сохранить и подключиться") {
                    AppConfigStore.save(config)
                    supabase.configure(with: config)
                }
                .buttonStyle(.primaryFilled)
                .disabled(!config.isConfigured)

                Button("Вернуть настройки по умолчанию") {
                    AppConfigStore.resetToDefaults()
                    config = AppConfigStore.load()
                    supabase.configure(with: config)
                }
                .font(.footnote)
                .tint(Theme.accent)
            }
            .padding(.top, Theme.Spacing.sm)
        } label: {
            Text("Настройки подключения")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
        }
        .card()
    }

    private func authenticate() async {
        isBusy = true
        defer { isBusy = false }

        let succeeded = isRegistering
            ? await supabase.signUp(email: email, password: password)
            : await supabase.signIn(email: email, password: password)

        if succeeded {
            password = ""
        } else {
            alertMessage = supabase.lastErrorMessage ?? AuthMessage.invalidCredentials
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
