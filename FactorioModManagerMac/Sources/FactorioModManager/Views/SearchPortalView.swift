import SwiftUI

public struct SearchPortalView: View {
    @ObservedObject var appState: AppState
    @State private var queryText: String = ""
    @State private var selectedVersion: String = "2.1-recent"
    @FocusState private var isSearchFocused: Bool

    private func performSearch() {
        Task {
            await appState.searchPortal(query: queryText, version: selectedVersion)
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
                            .focused($isSearchFocused)
                            .onSubmit { performSearch() }

                        if !queryText.isEmpty {
                            Button(action: {
                                queryText = ""
                                Task {
                                    await appState.loadPortalCatalog(version: selectedVersion)
                                }
                            }) {
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
                    .disabled(appState.isSearching)
                }

                // Version Filter: 2.1 Recent, 2.1 All, 2.0
                HStack {
                    Picker("", selection: $selectedVersion) {
                        Text(loc("filter_2_1_recent")).tag("2.1-recent")
                        Text(loc("filter_2_1_all")).tag("2.1")
                        Text(loc("filter_2_0")).tag("2.0")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                    .onChange(of: selectedVersion) { newVer in
                        Task {
                            await appState.searchPortal(query: queryText, version: newVer)
                        }
                    }

                    Spacer()

                    if !appState.searchResults.isEmpty {
                        Text(loc("search_results_by_date", appState.searchResults.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                    Text(queryText.isEmpty ? loc("loading_catalog", selectedVersion) : loc("searching"))
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
                    Text("No mods found for Factorio \(selectedVersion).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Reload Catalog") {
                        Task {
                            await appState.loadPortalCatalog(version: selectedVersion)
                        }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.searchResults) { item in
                    let isInstalled = appState.installedModsMap[item.name] != nil

                    UnifiedModCardRow(
                        name: item.name,
                        title: item.title,
                        owner: item.owner,
                        factorioVersions: item.factorioVersions,
                        lastUpdated: item.lastUpdated,
                        downloadsCount: item.downloadsCount,
                        summary: item.summary,
                        isDeprecated: item.isDeprecated,
                        isInstalled: isInstalled,
                        onInstall: {
                            Task { await appState.resolveAndInstall(targets: [item.name]) }
                        },
                        onOpenDetails: {
                            appState.openModDetails(for: item.name)
                        }
                    )
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .onAppear {
            if appState.searchResults.isEmpty {
                Task {
                    await appState.loadPortalCatalog(version: selectedVersion)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusModSearch)) { _ in
            isSearchFocused = true
        }
    }
}
