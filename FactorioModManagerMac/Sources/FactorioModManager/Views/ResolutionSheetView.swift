import SwiftUI

public struct ResolutionSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    private var isDownloadFinished: Bool {
        !appState.downloadProgressList.isEmpty &&
        !appState.isDownloading &&
        appState.downloadProgressList.allSatisfy { $0.isCompleted }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("resolution_plan_title"))
                        .font(.title3.bold())
                    if let res = appState.currentResolutionResult {
                        Text(loc("installation_plan_summary", res.modsToDownload.count, res.modsUpToDate.count))
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
                        // Conflicts Section (Monochrome alert with warning symbol)
                        if !res.conflicts.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.primary)
                                    Text(loc("conflicts_section"))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                ForEach(res.conflicts) { conf in
                                    Text("• \(conf.reason)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        // Missing Mods Section
                        if !res.missingMods.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(.primary)
                                    Text(loc("missing_section"))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                ForEach(res.missingMods) { m in
                                    Text("• \(m.name) (requested by: \(m.requiredBy))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        // Warnings Section
                        if !res.warnings.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc("warnings_section"))
                                    .font(.headline)
                                ForEach(res.warnings, id: \.self) { w in
                                    Text("• \(w)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
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

                                ForEach(res.modsToDownload) { mod in
                                    HStack {
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundColor(.secondary)
                                        Text(mod.name)
                                            .font(.system(size: 13, weight: .semibold))

                                        VersionBadge(mod.release.version.raw)

                                        if let old = mod.installedVersion {
                                            Text(loc("current_version_label", old.raw))
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        StatusBadge(
                                            mod.action == .update ? loc("status_update") : loc("status_new")
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
                                        Image(systemName: "checkmark.circle")
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

                if let res = appState.currentResolutionResult {
                    if !res.modsToDownload.isEmpty {
                        if isDownloadFinished {
                            Button(action: {
                                dismiss()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(loc("download_completed_installed"))
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
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
                                        Image(systemName: "arrow.down.circle")
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
                    } else if !res.modsUpToDate.isEmpty {
                        Button(action: {
                            Task {
                                await appState.executeDownload(for: [])
                                dismiss()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text(loc("enable_all_mods", res.modsUpToDate.count))
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 540, minHeight: 460)
        .onDisappear {
            appState.downloadProgressList = []
        }
    }
}
