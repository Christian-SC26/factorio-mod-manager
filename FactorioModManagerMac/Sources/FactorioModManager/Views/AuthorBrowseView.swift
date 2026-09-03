import SwiftUI

public struct AuthorBrowseView: View {
    @ObservedObject var appState: AppState
    @State private var authorInput: String = ""
    @StateObject private var nav = DiscoveryNavCoordinator(targetTab: .authors)
    @FocusState private var isInputFocused: Bool

    private func performFetch() {
        guard !authorInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        nav.selectedModNames.removeAll()
        nav.focusedIndex = 0
        isInputFocused = false
        Task {
            await appState.fetchAuthorMods(author: authorInput)
        }
    }

    private var activeCount: Int {
        appState.authorResults.filter { !$0.isDeprecated }.count
    }

    private var deprecatedCount: Int {
        appState.authorResults.filter { $0.isDeprecated }.count
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "person")
                            .foregroundColor(.secondary)
                        TextField(loc("author_input_placeholder"), text: $authorInput)
                            .textFieldStyle(.plain)
                            .focused($isInputFocused)
                            .onSubmit { performFetch() }

                        if !authorInput.isEmpty {
                            Button(action: { authorInput = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button(action: performFetch) {
                        HStack(spacing: 5) {
                            if appState.isFetchingAuthor {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.right")
                            }
                            Text(loc("fetch_author_button"))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authorInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isFetchingAuthor)
                }

                // Author Presets
                HStack(spacing: 8) {
                    Text(loc("popular_authors"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(["Earendel", "Raiguard", "Bilka", "snouz", "Klonan"], id: \.self) { author in
                        Button(author) {
                            authorInput = author
                            performFetch()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content
            if appState.isFetchingAuthor {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(loc("fetching_author"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.authorResults.isEmpty && !appState.currentAuthorName.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 42))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(loc("author_not_found", appState.currentAuthorName))
                        .font(.headline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.authorResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "person.2")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(loc("author_title"))
                        .font(.title3.bold())
                    Text(loc("author_browse_desc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Results with stats & multi-select install bar
                VStack(spacing: 0) {
                    HStack {
                        Text(String(format: loc("author_summary"), appState.authorResults.count, appState.currentAuthorName, activeCount, deprecatedCount))
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)

                        Spacer()

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
                        }

                        Button(nav.selectedModNames.count == appState.authorResults.count ? loc("deselect_all") : loc("select_all")) {
                            nav.toggleSelectAll(items: appState.authorResults.map(\.name))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                    Divider()

                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(appState.authorResults.enumerated()), id: \.element.id) { index, item in
                                let isInstalled = appState.installedModsMap[item.name] != nil
                                let isSelected = nav.selectedModNames.contains(item.name)
                                let isFocused = (index == nav.focusedIndex)

                                UnifiedModCardRow(
                                    name: item.name,
                                    title: item.title,
                                    owner: item.owner.isEmpty ? appState.currentAuthorName : item.owner,
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
                            let names = appState.authorResults.map(\.name)
                            if newIndex >= 0 && newIndex < names.count {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    proxy.scrollTo(names[newIndex], anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            nav.start(
                appState: appState,
                getItemNames: { appState.authorResults.map(\.name) },
                onFocusSearch: { isInputFocused = true }
            )
            if !appState.currentAuthorName.isEmpty {
                authorInput = appState.currentAuthorName
            }
        }
        .onDisappear {
            nav.stop()
        }
        .onChange(of: appState.authorResults.count) { newCount in
            nav.clampIndex(count: newCount)
        }
        .onChange(of: appState.currentAuthorName) { newAuthor in
            if !newAuthor.isEmpty {
                authorInput = newAuthor
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusModSearch)) { _ in
            isInputFocused = true
        }
    }
}
