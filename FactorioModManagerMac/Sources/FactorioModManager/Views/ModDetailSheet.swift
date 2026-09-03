import SwiftUI
import AppKit

public struct ModDetailSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var activeTab: Int = 0

    private var localMod: LocalMod? {
        appState.selectedModDetail
    }

    private var modInfo: ModInfo? {
        appState.selectedModInfoDetail
    }

    private var titleText: String {
        modInfo?.title ?? localMod?.title ?? loc("mod_details_title")
    }

    private var nameText: String {
        modInfo?.name ?? localMod?.name ?? ""
    }

    private var authorText: String {
        modInfo?.owner ?? localMod?.author ?? loc("unknown_author")
    }

    private var summaryText: String {
        modInfo?.summary ?? localMod?.summary ?? ""
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(titleText)
                        .font(.title2.bold())
                    Text(nameText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Badges row
                    HStack(spacing: 12) {
                        if !authorText.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person")
                                    .foregroundColor(.secondary)
                                Text(authorText)
                                    .fontWeight(.medium)
                            }
                            .font(.caption)
                        }

                        if let info = modInfo {
                            if !info.category.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag")
                                        .foregroundColor(.secondary)
                                    Text(info.category)
                                }
                                .font(.caption)
                            }

                            if info.downloadsCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                    Text(String(format: loc("downloads_count_badge"), Formatters.formatDownloads(info.downloadsCount)))
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }

                        if let local = localMod {
                            StatusBadge(local.enabled ? loc("enabled_status") : loc("disabled_status"), icon: local.enabled ? "checkmark.circle" : "xmark.circle")
                        }
                    }

                    // Screenshots Gallery
                    if let info = modInfo, !info.screenshots.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loc("screenshots_title"))
                                .font(.headline)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(info.screenshots) { shot in
                                        AsyncImage(url: URL(string: shot.thumbnail)) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            case .failure:
                                                Color.secondary.opacity(0.1)
                                                    .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                                            case .empty:
                                                ProgressView()
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .frame(width: 220, height: 130)
                                        .background(Color.secondary.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                                        .onTapGesture {
                                            if let u = URL(string: shot.url) {
                                                NSWorkspace.shared.open(u)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // Section tabs: Description, Changelog, Releases
                    Picker("", selection: $activeTab) {
                        Text(loc("description_tab")).tag(0)
                        Text(loc("changelog_tab")).tag(1)
                        Text(loc("releases_tab")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 380)
                    .padding(.top, 4)

                    // Tab Content
                    if activeTab == 0 {
                        // Description
                        VStack(alignment: .leading, spacing: 10) {
                            if let info = modInfo, !info.description.isEmpty {
                                Text(info.description)
                                    .font(.system(size: 13))
                                    .textSelection(.enabled)
                            } else if !summaryText.isEmpty {
                                Text(summaryText)
                                    .font(.system(size: 13))
                                    .textSelection(.enabled)
                            } else {
                                Text(loc("no_full_description"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if activeTab == 1 {
                        // Changelog
                        VStack(alignment: .leading, spacing: 8) {
                            if let info = modInfo, !info.changelog.isEmpty {
                                Text(info.changelog)
                                    .font(.system(size: 12, design: .monospaced))
                                    .textSelection(.enabled)
                            } else {
                                Text(loc("no_changelog"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        // Releases & Dependencies
                        VStack(alignment: .leading, spacing: 14) {
                            if let latest = modInfo?.getLatestRelease(targetFactorioBranch: appState.effectiveFactorioVersion) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(loc("latest_release_label"))
                                        .font(.headline)

                                    HStack(spacing: 10) {
                                        VersionBadge(latest.version.raw)
                                        Text(loc("factorio_version_prefix", latest.factorioVersion))
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if !latest.releasedAt.isEmpty {
                                            Text(loc("released_date_prefix", latest.releasedAt))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    if !latest.dependencies.isEmpty {
                                        Text(String(format: loc("dependencies_label"), latest.dependencies.count))
                                            .font(.subheadline.bold())
                                            .padding(.top, 4)

                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(latest.dependencies, id: \.self) { dep in
                                                HStack(spacing: 6) {
                                                    DependencyBadge(type: dep.depType)
                                                    Text(dep.name)
                                                        .font(.system(size: 12, weight: .semibold))
                                                    if let op = dep.op, let v = dep.version {
                                                        Text("\(op) \(v.raw)")
                                                            .font(.system(size: 11, design: .monospaced))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.vertical, 2)
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            if let local = localMod {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(loc("local_file_section"))
                                        .font(.headline)

                                    HStack {
                                        Text(local.fileURL.lastPathComponent)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if local.fileSize > 0 {
                                            Text(formatBytes(local.fileSize))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // Footer Actions
            HStack {
                Button(loc("close_button")) {
                    dismiss()
                }

                if let url = URL(string: "https://mods.factorio.com/mod/\(nameText)") {
                    Button(action: { NSWorkspace.shared.open(url) }) {
                        Label(loc("open_on_portal"), systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                if let local = localMod {
                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([local.fileURL]) }) {
                        Label(loc("reveal_in_finder"), systemImage: "folder")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }

                Spacer()

                let isInstalled = appState.installedModsMap[nameText] != nil || localMod != nil
                if isInstalled {
                    Button(action: {}) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark")
                            Text(loc("installed_status"))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                } else {
                    Button(action: {
                        dismiss()
                        Task { await appState.resolveAndInstall(targets: [nameText]) }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle")
                            Text(loc("install_button"))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 640, minHeight: 520)
    }
}
