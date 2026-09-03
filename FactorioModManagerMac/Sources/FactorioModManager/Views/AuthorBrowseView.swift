import SwiftUI

public struct AuthorBrowseView: View {
    @ObservedObject var appState: AppState
    @State private var authorInput: String = ""
    @State private var selectedModNames: Set<String> = []
    @FocusState private var isInputFocused: Bool

    private func performFetch() {
        guard !authorInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        selectedModNames.removeAll()
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

                        if !selectedModNames.isEmpty {
                            Button(action: {
                                Task {
                                    await appState.resolveAndInstall(targets: Array(selectedModNames))
                                    selectedModNames.removeAll()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                    Text(String(format: loc("install_selected"), selectedModNames.count))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button(selectedModNames.count == appState.authorResults.count ? loc("deselect_all") : loc("select_all")) {
                            if selectedModNames.count == appState.authorResults.count {
                                selectedModNames.removeAll()
                            } else {
                                selectedModNames = Set(appState.authorResults.map { $0.name })
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                    Divider()

                    List(appState.authorResults) { item in
                        let isInstalled = appState.installedModsMap[item.name] != nil
                        let isSelected = selectedModNames.contains(item.name)

                        HStack(spacing: 12) {
                            Button(action: {
                                if isSelected {
                                    selectedModNames.remove(item.name)
                                } else {
                                    selectedModNames.insert(item.name)
                                }
                            }) {
                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 15))
                                    .foregroundColor(isSelected ? .primary : .secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .semibold))

                                    Text("(\(item.name))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 10) {
                                    if !item.factorioVersions.isEmpty {
                                        Text("Factorio: \(item.factorioVersions)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    if item.downloadsCount > 0 {
                                        Text("\(Formatters.formatDownloads(item.downloadsCount)) dl")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            if isInstalled {
                                StatusBadge(loc("installed_status"), icon: "checkmark.circle")
                            }

                            if item.isDeprecated {
                                StatusBadge(loc("deprecated_badge"), icon: "exclamationmark.triangle")
                            }

                            Button(action: {
                                Task { await appState.resolveAndInstall(targets: [item.name]) }
                            }) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help(loc("install_button"))
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusModSearch)) { _ in
            isInputFocused = true
        }
    }
}
