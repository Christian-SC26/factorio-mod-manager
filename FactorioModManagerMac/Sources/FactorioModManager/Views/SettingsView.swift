import SwiftUI
import AppKit
import MarkdownUI

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var locMgr = LocalizationManager.shared
    @ObservedObject var updates = AppUpdateManager.shared
    @State private var selectedVersionOption: String = "auto"

    private func chooseCustomModsDir() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = loc("select_folder")

        if openPanel.runModal() == .OK, let url = openPanel.url {
            appState.setModsDirectory(url)
        }
    }

    @ViewBuilder
    private var appUpdateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    Task { await updates.check() }
                } label: {
                    Label(loc("app_update_check_button"), systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(updates.isBusy)
                .fixedSize(horizontal: true, vertical: false)

                appUpdateStatus

                Spacer()
            }

            Toggle(loc("app_update_auto_check"), isOn: $updates.checkAutomatically)
                .font(.caption)

            if let release = updates.available {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("app_update_available", release.version.description))
                        .fontWeight(.semibold)

                    if !release.notes.isEmpty {
                        ScrollView {
                            Markdown(release.notes)
                                .markdownTheme(.gitHub)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180)
                    }

                    if let blocker = updates.installBlocker {
                        Text(loc(blocker))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button {
                            Task { await updates.install() }
                        } label: {
                            Label(loc("app_update_install_button"), systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(updates.isBusy || updates.installBlocker != nil)
                        .fixedSize(horizontal: true, vertical: false)

                        Link(loc("app_update_release_page"), destination: release.pageURL)
                            .font(.caption)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var appUpdateStatus: some View {
        switch updates.status {
        case .idle:
            EmptyView()
        case .checking, .downloading, .installing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(loc(updates.status == .checking ? "app_update_checking"
                    : updates.status == .downloading ? "app_update_downloading" : "app_update_installing"))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        case .upToDate:
            Label(loc("app_update_up_to_date"), systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        case .failed(let message):
            Label(loc("app_update_failed", message), systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.orange)
                .textSelection(.enabled)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("settings_title"))
                        .font(.title2.bold())
                    Text(loc("settings_desc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Mods Directory Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("mods_directory_title"))
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.modsDirectory.path)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        HStack(spacing: 10) {
                            Button(action: chooseCustomModsDir) {
                                Label(loc("select_folder"), systemImage: "folder")
                            }
                            .fixedSize(horizontal: true, vertical: false)

                            Button(action: {
                                NSWorkspace.shared.open(appState.modsDirectory)
                            }) {
                                Label(loc("open_mods_folder"), systemImage: "arrow.up.forward.square")
                            }
                            .fixedSize(horizontal: true, vertical: false)

                            Spacer()

                            Button(loc("reset_default")) {
                                appState.resetModsDirectory()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Target Factorio Branch
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("factorio_version_title"))
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        Picker(loc("branch_version_picker_label"), selection: $selectedVersionOption) {
                            Text(String(format: loc("auto_detect_label"), appState.detectedFactorioVersion)).tag("auto")
                            Text(loc("factorio_2_1_label")).tag("2.1")
                            Text(loc("factorio_2_0_label")).tag("2.0")
                            Text(loc("custom_version_label")).tag("custom")
                        }
                        .pickerStyle(.menu)
                        .fixedSize(horizontal: true, vertical: false)
                        .onChange(of: selectedVersionOption) { val in
                            if val == "auto" {
                                appState.customFactorioVersion = ""
                            } else if val != "custom" {
                                appState.customFactorioVersion = val
                            }
                        }

                        if selectedVersionOption == "custom" {
                            HStack {
                                Text(loc("custom_version_field_label"))
                                    .font(.subheadline)
                                TextField("e.g. 2.1.17", text: $appState.customFactorioVersion)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 160)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Download & Storage Behavior
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("download_management_rules_title"))
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $appState.cleanOldVersions) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc("clean_old_title"))
                                    .fontWeight(.medium)
                                Text(loc("clean_old_desc"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        Toggle(isOn: $appState.autoEnableMods) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc("auto_enable_title"))
                                    .fontWeight(.medium)
                                Text(loc("auto_enable_desc"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Language Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("language_title"))
                        .font(.headline)

                    HStack {
                        Picker("", selection: Binding(
                            get: { locMgr.language },
                            set: { locMgr.setLanguage($0) }
                        )) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // About Section
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("about_title"))
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Factorio Mod Manager")
                            .font(.system(size: 14, weight: .bold))
                        Text(loc("version_label", updates.currentVersion?.description ?? loc("version_dev")))
                            .font(.caption)
                            .foregroundColor(.secondary)


                        Link(destination: URL(string: "https://github.com/Christian-SC26/factorio-mod-manager")!) {
                            HStack(spacing: 5) {
                                Image(systemName: "link")
                                    .font(.system(size: 11))
                                Text("https://github.com/Christian-SC26/factorio-mod-manager")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.link)

                        Divider()
                            .padding(.vertical, 4)

                        appUpdateSection
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            if appState.customFactorioVersion.isEmpty {
                selectedVersionOption = "auto"
            } else if ["2.1", "2.0", "1.1"].contains(appState.customFactorioVersion) {
                selectedVersionOption = appState.customFactorioVersion
            } else {
                selectedVersionOption = "custom"
            }
        }
    }
}
