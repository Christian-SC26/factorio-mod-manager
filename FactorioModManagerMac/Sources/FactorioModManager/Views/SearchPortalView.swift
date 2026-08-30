import SwiftUI

public struct SearchPortalView: View {
    @ObservedObject var appState: AppState
    @State private var queryText: String = ""
    @State private var searchScope: Int = 1 // 0: All, 1: v2 only, 2: local

    private func performSearch() {
        guard !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            await appState.searchPortal(query: queryText, scope: searchScope)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(loc("search_input_placeholder"), text: $queryText)
                            .textFieldStyle(.plain)
                            .onSubmit { performSearch() }

                        if !queryText.isEmpty {
                            Button(action: { queryText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button(action: performSearch) {
                        HStack(spacing: 5) {
                            if appState.isSearching {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(loc("search_button"))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isSearching)
                }

                // Scope Picker
                HStack {
                    Picker("", selection: $searchScope) {
                        Text(loc("scope_v2")).tag(1)
                        Text(loc("scope_all")).tag(0)
                        Text(loc("scope_local")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 380)

                    Spacer()
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Results Area
            if appState.isSearching {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(loc("searching"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.searchResults.isEmpty && !appState.lastSearchQuery.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(String(format: loc("no_search_results"), appState.lastSearchQuery))
                        .font(.headline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "globe")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(loc("search_portal_title"))
                        .font(.title3.bold())
                    Text("Search thousands of Factorio mods online and install with one click.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.searchResults) { item in
                    let isInstalled = appState.installedModsMap[item.name] != nil

                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .bold))

                                Text("(\(item.name))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)

                                if isInstalled {
                                    StatusBadge(loc("installed_status"), icon: "checkmark.circle")
                                }

                                if item.isDeprecated {
                                    StatusBadge(loc("deprecated_badge"), icon: "exclamationmark.triangle")
                                }
                            }

                            HStack(spacing: 12) {
                                if !item.owner.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person")
                                        Text(item.owner)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }

                                if !item.factorioVersions.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "tag")
                                        Text(item.factorioVersions)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }

                                if item.downloadsCount > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle")
                                        Text(String(format: loc("downloads_count_badge"), "\(item.downloadsCount)"))
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }

                            if !item.summary.isEmpty {
                                Text(item.summary)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .padding(.top, 2)
                            }
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            if isInstalled {
                                Button(action: {}) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark")
                                        Text("Installed")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .disabled(true)
                            } else {
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
                            }

                            Button(action: {
                                appState.openModDetails(for: item.name)
                            }) {
                                Text("Details")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}
