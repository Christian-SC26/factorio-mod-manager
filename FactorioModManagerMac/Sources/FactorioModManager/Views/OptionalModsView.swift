import SwiftUI

public struct OptionalModsView: View {
    @ObservedObject var appState: AppState
    @State private var hasScanned: Bool = false

    private func performScan() {
        hasScanned = true
        appState.scanOptionalMods()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("optional_title"))
                        .font(.title2.bold())
                    Text(loc("optional_desc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: performScan) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                            Text(loc("scan_optional_button"))
                        }
                    }

                    if !appState.optionalMods.isEmpty {
                        Button(action: {
                            let targets = appState.optionalMods.map { $0.name }
                            Task { await appState.resolveAndInstall(targets: targets) }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Install All (\(appState.optionalMods.count))")
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
            if appState.optionalMods.isEmpty && hasScanned {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text(loc("no_optional_found"))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.optionalMods.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "puzzlepiece.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.yellow)
                    Text(loc("optional_title"))
                        .font(.title3.bold())
                    Text("Click the button below to scan your installed mods for suggested and optional companion mods.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    Button(action: performScan) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text(loc("scan_optional_button"))
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.optionalMods) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.yellow)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.system(size: 14, weight: .semibold))

                            HStack(spacing: 4) {
                                Text(loc("suggested_by"))
                                    .foregroundColor(.secondary)
                                Text(item.suggestedBy.joined(separator: ", "))
                                    .fontWeight(.medium)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            Task { await appState.resolveAndInstall(targets: [item.name]) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text(loc("install_button"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .onAppear {
            if appState.optionalMods.isEmpty {
                performScan()
            }
        }
    }
}
