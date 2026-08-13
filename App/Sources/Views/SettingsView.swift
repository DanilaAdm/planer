import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.openURL) private var openURL
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
                            if env.pendingChangesCount > 0 {
                                RowDivider()
                                settingRow(
                                    title: "Ждут отправки",
                                    value: "\(env.pendingChangesCount)"
                                )
                                Text("Изменения сохранены на устройстве и уедут на сервер, как только появится интернет.")
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            RowDivider()
                            Button("Обновить данные") {
                                Task { await env.reloadAll() }
                            }
                            .buttonStyle(.secondarySoft)

                            Button("Отправить данные этого устройства на сервер") {
                                Task { await env.uploadLocalData() }
                            }
                            .buttonStyle(.secondarySoft)
                            .disabled(env.isSyncing)
                            Text("Пригодится, если на этом устройстве ученики и расписание есть, а на другом их не видно.")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }

                    SectionCard(title: "О приложении") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            settingRow(title: "Версия", value: appVersion)
                            RowDivider()
                            updateStatus
                            Button("Проверить обновления") {
                                Task { await updates.check(force: true) }
                            }
                            .buttonStyle(.secondarySoft)
                            .disabled(updates.status == .checking)
                        }
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

    /// Что известно про обновления. Кнопка «Скачать» появляется только тогда,
    /// когда на GitHub действительно лежит версия новее установленной.
    @ViewBuilder
    private var updateStatus: some View {
        switch updates.status {
        case .idle:
            Text("Приложение обновляется вручную: новая версия скачивается с GitHub.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        case .checking:
            Text("Проверяем наличие обновлений…")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        case .upToDate:
            HStack {
                Text("Обновления")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                StatusChip(text: "Последняя версия", systemImage: "checkmark", kind: .success)
            }
        case .failed:
            Text("Не удалось проверить обновления — нет связи с GitHub.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        case let .available(release):
            HStack {
                Text("Доступна версия \(release.version.description)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                StatusChip(text: "Обновление", systemImage: "arrow.down.circle", kind: .accent)
            }
            Button("Скачать обновление") {
                openURL(release.updateURL)
            }
            .buttonStyle(.primaryFilled)
            Text("Откроется загрузка с GitHub. Данные хранятся на сервере и при обновлении не теряются.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
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
        "\(Bundle.main.marketingVersion) (\(Bundle.main.buildNumber))"
    }
}
