import SwiftUI

/// Полоса поверх разделов, когда сервер недоступен.
///
/// Без неё пустой планер на новом устройстве неотличим от потери данных:
/// приложение показывало бы пустой кэш и молчало о том, что загрузка не удалась.
struct SyncBanner: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        if !env.isOnline {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Нет связи с сервером")
                        .font(.footnote.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Theme.ink.opacity(0.75))
                }

                Spacer(minLength: Theme.Spacing.sm)

                Button("Повторить") {
                    Task { await env.reloadAll() }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .disabled(env.isSyncing)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.warning.opacity(0.18))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.warning.opacity(0.45))
                    .frame(height: Theme.Stroke.hairline)
            }
            .accessibilityIdentifier("syncBanner")
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var subtitle: String {
        if env.pendingChangesCount > 0 {
            return "Показаны сохранённые данные. Не отправлено изменений: \(env.pendingChangesCount)."
        }
        return "Показаны сохранённые на устройстве данные — они могут быть неполными."
    }
}
