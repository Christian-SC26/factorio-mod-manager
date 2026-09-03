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
                                Image(systemName: "arrow.down.circle")
                                Text(loc("install_all_count", appState.optionalMods.count))
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
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
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
                    Image(systemName: "puzzlepiece")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(loc("optional_title"))
                        .font(.title3.bold())
                    Text(loc("optional_mods_empty_desc"))
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
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "cube.box")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.system(size: 13, weight: .bold))

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

                            VStack(spacing: 6) {
                                Button(action: {
                                    Task { await appState.resolveAndInstall(targets: [item.name]) }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle")
                                        Text(loc("install_button"))
                                            .fontWeight(.semibold)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)

                                Button(action: {
                                    appState.openModDetails(for: item.name)
                                }) {
                                    Text(loc("details_button"))
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.openModDetails(for: item.name)
                        }
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
