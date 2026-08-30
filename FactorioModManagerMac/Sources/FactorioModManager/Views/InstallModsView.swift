import SwiftUI

public struct InstallModsView: View {
    @ObservedObject var appState: AppState
    @State private var inputText: String = ""
    @State private var includeRecommended: Bool = true
    @State private var includeOptional: Bool = false
    @State private var forceReinstall: Bool = false

    private func parseTargets() -> [String] {
        let cleaned = inputText
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: ",", with: " ")
        return cleaned.components(separatedBy: " ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("install_title"))
                        .font(.title2.bold())
                    Text("Install mods directly from mirror with full automatic recursive dependency resolution.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Input Area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mod URLs or Names:")
                        .font(.headline)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )

                        if inputText.isEmpty {
                            Text(loc("install_input_placeholder"))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                    }

                    // Quick example presets
                    HStack(spacing: 8) {
                        Text("Popular:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Space Exploration") {
                            inputText = "https://mods.factorio.com/mod/space-exploration"
                        }
                        .buttonStyle(.link)
                        .font(.caption)

                        Button("Krastorio 2") {
                            inputText = "Krastorio2"
                        }
                        .buttonStyle(.link)
                        .font(.caption)

                        Button("Pyanodons") {
                            inputText = "pycoalprocessing pyrawores pyfusionenergy"
                        }
                        .buttonStyle(.link)
                        .font(.caption)

                        Button("flib") {
                            inputText = "flib"
                        }
                        .buttonStyle(.link)
                        .font(.caption)

                        Spacer()

                        if !inputText.isEmpty {
                            Button("Clear") {
                                inputText = ""
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }

                // Options Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dependency & Download Options")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(loc("include_recommended"), isOn: $includeRecommended)
                        Toggle(loc("include_optional"), isOn: $includeOptional)
                        Toggle(loc("force_reinstall"), isOn: $forceReinstall)
                        Toggle(loc("clean_old_versions"), isOn: $appState.cleanOldVersions)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Resolve Button
                HStack {
                    Spacer()
                    Button(action: {
                        let targets = parseTargets()
                        Task {
                            await appState.resolveDependencies(
                                targets: targets,
                                includeRecommended: includeRecommended,
                                includeOptional: includeOptional,
                                forceReinstall: forceReinstall
                            )
                        }
                    }) {
                        HStack(spacing: 6) {
                            if appState.isResolving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text(loc("resolve_and_preview"))
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(parseTargets().isEmpty || appState.isResolving)
                }

                Spacer()
            }
            .padding(24)
        }
    }
}
