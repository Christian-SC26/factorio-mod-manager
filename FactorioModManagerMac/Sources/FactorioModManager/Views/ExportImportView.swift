import SwiftUI
import AppKit

public struct ExportImportView: View {
    @ObservedObject var appState: AppState

    private func handleExport(format: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = format == "json" ? [.json] : [.plainText]
        savePanel.nameFieldStringValue = format == "json" ? "modpack.json" : "modpack.txt"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let count = try appState.modListMgr.exportModpack(to: url)
                appState.showNotification(
                    title: loc("export_import_title"),
                    message: String(format: loc("exported_success"), count, url.lastPathComponent)
                )
            } catch {
                appState.showNotification(
                    title: loc("export_import_title"),
                    message: error.localizedDescription,
                    isError: true
                )
            }
        }
    }

    private func handleImport() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json, .plainText]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let targets = try appState.modListMgr.importModpack(from: url)
                guard !targets.isEmpty else {
                    appState.showNotification(
                        title: loc("export_import_title"),
                        message: loc("no_mods_in_import_file"),
                        isError: true
                    )
                    return
                }

                appState.showNotification(
                    title: loc("export_import_title"),
                    message: String(format: loc("imported_success"), targets.count, url.lastPathComponent)
                )

                Task {
                    await appState.resolveAndInstall(targets: targets)
                }
            } catch {
                appState.showNotification(
                    title: loc("export_import_title"),
                    message: error.localizedDescription,
                    isError: true
                )
            }
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("export_import_title"))
                        .font(.title2.bold())
                    Text(loc("export_import_desc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Export Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("export_section_title"))
                                .font(.headline)
                            Text(loc("export_section_desc"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    let activeCount = appState.installedMods.filter { appState.isModEnabled($0.name) && $0.name != "base" }.count
                    Text(loc("active_mods_ready_for_export", activeCount))
                        .font(.subheadline.bold())

                    HStack(spacing: 12) {
                        Button(action: { handleExport(format: "json") }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.badge.arrow.up")
                                Text(loc("export_json_button"))
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: { handleExport(format: "txt") }) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet.rectangle")
                                Text(loc("export_txt_button"))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(18)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Import Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("import_section_title"))
                                .font(.headline)
                            Text(loc("import_section_desc"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    Button(action: handleImport) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                            Text(loc("import_file_button"))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(18)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()
            }
            .padding(24)
        }
    }
}
