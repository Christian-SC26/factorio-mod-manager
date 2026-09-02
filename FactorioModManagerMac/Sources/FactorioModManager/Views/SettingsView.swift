import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var locMgr = LocalizationManager.shared
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

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("settings_title"))
                        .font(.title2.bold())
                    Text("Configure mods storage directory, target Factorio branch, and manager behavior.")
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

                            Button(action: {
                                NSWorkspace.shared.open(appState.modsDirectory)
                            }) {
                                Label(loc("open_mods_folder"), systemImage: "arrow.up.forward.square")
                            }

                            Spacer()

                            Button(loc("reset_default")) {
                                appState.resetModsDirectory()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
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
                        Picker("Branch / Version", selection: $selectedVersionOption) {
                            Text(String(format: loc("auto_detect_label"), appState.detectedFactorioVersion)).tag("auto")
                            Text("2.1 (Current Latest)").tag("2.1")
                            Text("2.0 (Space Age)").tag("2.0")
                            Text("1.1 (Legacy)").tag("1.1")
                            Text("Custom").tag("custom")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 320)
                        .onChange(of: selectedVersionOption) { val in
                            if val == "auto" {
                                appState.customFactorioVersion = ""
                            } else if val != "custom" {
                                appState.customFactorioVersion = val
                            }
                        }

                        if selectedVersionOption == "custom" {
                            HStack {
                                Text("Custom Version:")
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
                    Text("Download & Management Rules")
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

                    Picker("", selection: Binding(
                        get: { locMgr.language },
                        set: { locMgr.setLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }

                // About Section
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("about_title"))
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Factorio Mod Manager (FMM)")
                                .font(.system(size: 14, weight: .bold))
                            StatusBadge("macOS Native")
                        }
                        Text(loc("version_label"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(loc("mirror_info"))
                            .font(.caption)
                            .foregroundColor(.secondary)
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
