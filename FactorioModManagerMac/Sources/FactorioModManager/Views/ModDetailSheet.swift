import SwiftUI
import AppKit

public struct ModDetailSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss

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
            // Header (Clean, no box icon)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.title2.bold())
                    Text(nameText)
                        .font(.system(.subheadline, design: .monospaced))
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

            // Content Scroll
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Meta badges row
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

                    // Summary
                    if !summaryText.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(loc("description_label"))
                                .font(.headline)
                            Text(summaryText)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    // Latest Release Info
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

                            // Dependencies
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

                    // Local File info if installed
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
        .frame(minWidth: 520, minHeight: 480)
    }
}
