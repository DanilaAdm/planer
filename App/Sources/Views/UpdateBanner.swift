import SwiftUI

/// Полоса «доступна новая версия» поверх всех разделов.
///
/// Появляется, только когда на GitHub действительно лежит релиз новее
/// установленного. Кнопка ведёт на файл сборки, крестик убирает полосу
/// до следующей версии.
struct UpdateBanner: View {
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let release = updates.bannerRelease {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Доступна новая версия \(release.version.description)")
                        .font(.footnote.weight(.semibold))
                    Text("Установлена \(updates.installedVersion). Обновление сохранит все данные.")
                        .font(.caption2)
                        .foregroundStyle(Theme.ink.opacity(0.75))
                }

                Spacer(minLength: Theme.Spacing.sm)

                Button("Обновить") {
                    openURL(release.updateURL)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("updateBannerAction")

                Button {
                    updates.dismissBanner()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Скрыть сообщение об обновлении")
                .accessibilityIdentifier("updateBannerDismiss")
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.12))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.accent.opacity(0.35))
                    .frame(height: Theme.Stroke.hairline)
            }
            .accessibilityIdentifier("updateBanner")
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
