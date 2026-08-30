import SwiftUI

public struct UpdatesView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("updates_title"))
                        .font(.title2.bold())
                    Text(appState.updatesAvailable.isEmpty ? "All installed mods are checked against latest releases." : "\(appState.updatesAvailable.count) updates available for installed mods.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: {
                        Task { await appState.checkForUpdates() }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .rotationEffect(.degrees(appState.isCheckingUpdates ? 360 : 0))
                                .animation(appState.isCheckingUpdates ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: appState.isCheckingUpdates)
                            Text(loc("check_updates"))
                        }
                    }
                    .disabled(appState.isCheckingUpdates)

                    if !appState.updatesAvailable.isEmpty {
                        Button(action: {
                            Task { await appState.updateAllMods() }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.circle")
                                Text(String(format: loc("update_all"), appState.updatesAvailable.count))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content
            if appState.isCheckingUpdates {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(loc("checking_for_updates"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.updatesAvailable.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(loc("no_updates_available"))
                        .font(.headline)
                    Text("Target Factorio branch: \(appState.effectiveFactorioVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.updatesAvailable) { update in
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(update.title)
                                .font(.system(size: 13, weight: .semibold))
                            Text(update.name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)

                            if !update.modInfo.summary.isEmpty {
                                Text(update.modInfo.summary)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        // Version diff (Monochrome)
                        HStack(spacing: 6) {
                            Text("v\(update.localVersion.raw)")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text("v\(update.remoteVersion.raw)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                        Button(action: {
                            Task { await appState.updateSingleMod(update) }
                        }) {
                            Text(loc("update_single"))
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}
