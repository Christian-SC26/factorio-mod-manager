import SwiftUI

public struct SearchPortalView: View {
    @ObservedObject var appState: AppState
    @State private var queryText: String = ""
    @State private var selectedVersion: String = "2.1-recent"
    @StateObject private var nav = DiscoveryNavCoordinator(targetTab: .search)
    @FocusState private var isSearchFocused: Bool

    private func performSearch() {
        nav.selectedModNames.removeAll()
        nav.focusedIndex = 0
        isSearchFocused = false
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
                                nav.selectedModNames.removeAll()
                                nav.focusedIndex = 0
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
                HStack(spacing: 10) {
                    Picker("", selection: $selectedVersion) {
                        Text(loc("filter_2_1_recent")).tag("2.1-recent")
                        Text(loc("filter_2_1_all")).tag("2.1")
                        Text(loc("filter_2_0")).tag("2.0")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                    .onChange(of: selectedVersion) { newVer in
                        nav.selectedModNames.removeAll()
                        nav.focusedIndex = 0
                        Task {
                            await appState.searchPortal(query: queryText, version: newVer)
                        }
                    }

                    Spacer()

                    if !appState.searchResults.isEmpty {
                        if !nav.selectedModNames.isEmpty {
                            Button(action: {
                                nav.installSelected(appState: appState)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                    Text(String(format: loc("install_selected"), nav.selectedModNames.count))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        Button(nav.selectedModNames.count == appState.searchResults.count ? loc("deselect_all") : loc("select_all")) {
                            nav.toggleSelectAll(items: appState.searchResults.map(\.name))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

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
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(appState.searchResults.enumerated()), id: \.element.id) { index, item in
                            let isInstalled = appState.installedModsMap[item.name] != nil
                            let isSelected = nav.selectedModNames.contains(item.name)
                            let isFocused = (index == nav.focusedIndex)

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
                                isSelected: isSelected,
                                isFocused: isFocused,
                                onSelectRow: {
                                    nav.focusedIndex = index
                                },
                                onToggleSelect: {
                                    nav.focusedIndex = index
                                    nav.toggleSelect(name: item.name)
                                },
                                onSelectAuthor: { author in
                                    appState.navigateToAuthor(author)
                                },
                                onInstall: {
                                    nav.focusedIndex = index
                                    Task { await appState.resolveAndInstall(targets: [item.name]) }
                                },
                                onOpenDetails: {
                                    nav.focusedIndex = index
                                    appState.openModDetails(for: item.name)
                                }
                            )
                            .id(item.name)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .onChange(of: nav.focusedIndex) { newIndex in
                        let names = appState.searchResults.map(\.name)
                        if newIndex >= 0 && newIndex < names.count {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                proxy.scrollTo(names[newIndex], anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            nav.start(
                appState: appState,
                getItemNames: { appState.searchResults.map(\.name) },
                onFocusSearch: { isSearchFocused = true }
            )
            if appState.searchResults.isEmpty {
                Task {
                    await appState.loadPortalCatalog(version: selectedVersion)
                }
            }
        }
        .onDisappear {
            nav.stop()
        }
        .onChange(of: appState.searchResults.count) { newCount in
            nav.clampIndex(count: newCount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusModSearch)) { _ in
            isSearchFocused = true
        }
    }
}
