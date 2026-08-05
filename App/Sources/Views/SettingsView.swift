import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @EnvironmentObject private var env: AppEnvironment
    @State private var config = AppConfigStore.load()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    SectionCard(title: "Аккаунт") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            if case let .signedIn(email) = supabase.authState {
                                settingRow(title: "Вход выполнен", value: email)
                                RowDivider()
                            }
                            Button("Выйти") {
                                Task { await supabase.signOut() }
                            }
                            .buttonStyle(.plain)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.destructive)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                    .fill(Theme.destructive.opacity(0.10))
                            )
                        }
                    }

                    SectionCard(title: "Подключение к Supabase") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            LabeledField(title: "Project URL", text: $config.supabaseURL)
                            LabeledField(title: "Anon-ключ", text: $config.supabaseAnonKey, secure: true)
                            Button("Сохранить") {
                                AppConfigStore.save(config)
                                supabase.configure(with: config)
                            }
                            .buttonStyle(.primaryFilled)
                            .disabled(!config.isConfigured)
                        }
                    }

                    SectionCard(title: "Синхронизация") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            HStack {
                                Text("Состояние")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                StatusChip(
                                    text: env.isOnline ? "Онлайн" : "Офлайн (кэш)",
                                    systemImage: env.isOnline ? "wifi" : "wifi.slash",
                                    kind: env.isOnline ? .success : .warning
                                )
                            }
                            RowDivider()
                            Button("Обновить данные") {
                                Task { await env.reloadAll() }
                            }
                            .buttonStyle(.secondarySoft)
                        }
                    }

                    SectionCard(title: "О приложении") {
                        settingRow(title: "Версия", value: appVersion)
                    }
                }
                .padding(Theme.Spacing.lg)
                .centeredContent()
            }
            .screenBackground()
            .tint(Theme.accent)
            .navigationTitle("Настройки")
        }
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
