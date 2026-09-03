import SwiftUI

public struct OptionalModsView: View {
    @ObservedObject var appState: AppState
    @State private var hasScanned: Bool = false
    @StateObject private var nav = DiscoveryNavCoordinator(targetTab: .optional)

    private func performScan() {
        hasScanned = true
        nav.selectedModNames.removeAll()
        nav.focusedIndex = 0
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
                        Button(nav.selectedModNames.count == appState.optionalMods.count ? loc("deselect_all") : loc("select_all")) {
                            nav.toggleSelectAll(items: appState.optionalMods.map(\.name))
                        }
                        .buttonStyle(.bordered)

                        if !nav.selectedModNames.isEmpty {
                            Button(action: {
                                nav.installSelected(appState: appState)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.down.circle")
                                    Text(String(format: loc("install_selected"), nav.selectedModNames.count))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
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
                        .font(.title3.bold())
                    Text(loc("no_optional_desc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.isScanningOptional {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(loc("scanning_optional"))
                        .font(.headline)
                        .foregroundColor(.secondary)
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
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(appState.optionalMods.enumerated()), id: \.element.id) { index, item in
                            let isInstalled = appState.installedModsMap[item.name] != nil
                            let local = appState.installedModsMap[item.name]?.first
                            let isSelected = nav.selectedModNames.contains(item.name)
                            let isFocused = (index == nav.focusedIndex)

                            UnifiedModCardRow(
                                name: item.name,
                                title: local?.displayTitle ?? item.title,
                                owner: local?.author ?? (item.owner.isEmpty ? nil : item.owner),
                                factorioVersions: item.factorioVersions.isEmpty ? (local?.factorioVersion ?? appState.effectiveFactorioBranch) : item.factorioVersions,
                                lastUpdated: nil,
                                downloadsCount: item.downloadsCount,
                                summary: local?.summary ?? (item.summary.isEmpty ? nil : item.summary),
                                isDeprecated: false,
                                isInstalled: isInstalled,
                                suggestedBy: item.suggestedBy,
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
                        let names = appState.optionalMods.map(\.name)
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
                getItemNames: { appState.optionalMods.map(\.name) },
                onFocusSearch: nil
            )
            if appState.optionalMods.isEmpty {
                performScan()
            }
        }
        .onDisappear {
            nav.stop()
        }
        .onChange(of: appState.optionalMods.count) { newCount in
            nav.clampIndex(count: newCount)
        }
    }
}
