import SwiftUI

public struct ResolutionSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("resolution_plan_title"))
                        .font(.title3.bold())
                    if let res = appState.currentResolutionResult {
                        Text("\(res.modsToDownload.count) to download, \(res.modsUpToDate.count) up to date")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(appState.isDownloading)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content Scroll
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let res = appState.currentResolutionResult {
                        // Conflicts Section
                        if !res.conflicts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(loc("conflicts_section"))
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                                ForEach(res.conflicts) { conf in
                                    Text("• \(conf.reason)")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        // Missing Mods Section
                        if !res.missingMods.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .foregroundColor(.yellow)
                                    Text(loc("missing_section"))
                                        .font(.headline)
                                        .foregroundColor(.yellow)
                                }
                                ForEach(res.missingMods) { m in
                                    Text("• \(m.name) (requested by: \(m.requiredBy))")
                                        .font(.subheadline)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.yellow.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        // Warnings Section
                        if !res.warnings.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc("warnings_section"))
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                ForEach(res.warnings, id: \.self) { w in
                                    Text("• \(w)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        // Download Queue Section (during or after download)
                        if !appState.downloadProgressList.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(loc("downloading_mods"))
                                    .font(.headline)

                                ForEach(appState.downloadProgressList) { p in
                                    DownloadProgressBar(progress: p)
                                }
                            }
                        }

                        // Mods to Download List
                        if !res.modsToDownload.isEmpty && appState.downloadProgressList.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: loc("mods_to_download_section"), res.modsToDownload.count))
                                    .font(.headline)
                                    .foregroundColor(.green)

                                ForEach(res.modsToDownload) { mod in
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.green)
                                        Text(mod.name)
                                            .font(.system(size: 13, weight: .semibold))

                                        VersionBadge(mod.release.version.raw)

                                        if let old = mod.installedVersion {
                                            Text("(current: v\(old.raw))")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        StatusBadge(
                                            mod.action == .update ? "Update" : "New",
                                            color: mod.action == .update ? .orange : .green
                                        )
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                            }
                        }

                        // Up-to-date Mods
                        if !res.modsUpToDate.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: loc("mods_up_to_date_section"), res.modsUpToDate.count))
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                ForEach(res.modsUpToDate) { mod in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.secondary)
                                        Text(mod.name)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                        VersionBadge(mod.release.version.raw)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        // Dependency Tree
                        if !res.dependencyGraph.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(loc("dependency_tree"))
                                    .font(.headline)

                                DependencyTreeView(roots: res.rootMods, graph: res.dependencyGraph)
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
                .disabled(appState.isDownloading)

                Spacer()

                if let res = appState.currentResolutionResult, !res.modsToDownload.isEmpty {
                    Button(action: {
                        Task {
                            await appState.executeDownload(for: res.modsToDownload)
                        }
                    }) {
                        HStack(spacing: 6) {
                            if appState.isDownloading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text(loc("start_download"))
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(appState.isDownloading)
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 540, minHeight: 460)
    }
}
