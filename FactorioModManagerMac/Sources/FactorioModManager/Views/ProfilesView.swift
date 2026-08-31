import SwiftUI

public struct ProfilesView: View {
    @ObservedObject var appState: AppState
    @State private var newProfileName: String = ""
    @State private var profileToDelete: Profile? = nil
    @State private var showDeleteConfirmation: Bool = false

    private var currentActiveModNames: Set<String> {
        Set(appState.installedMods.filter { appState.isModEnabled($0.name) && $0.name != "base" }.map(\.name))
    }

    private func isProfileActive(_ profile: Profile) -> Bool {
        let activeMods = profile.extractActiveMods()
        return activeMods == currentActiveModNames
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("profiles_title"))
                        .font(.title2.bold())
                    Text(loc("profiles_desc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Save Current Profile Box
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("save_current_profile"))
                        .font(.headline)

                    HStack(spacing: 10) {
                        TextField(loc("profile_name_placeholder"), text: $newProfileName)
                            .textFieldStyle(.roundedBorder)

                        Button(action: {
                            guard !newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            appState.saveCurrentProfile(name: newProfileName)
                            newProfileName = ""
                        }) {
                            Label(loc("save_button"), systemImage: "plus")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Text("Saves all currently active mods (\(currentActiveModNames.count)) into a new profile.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Profiles List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved Profiles (\(appState.profiles.count))")
                        .font(.headline)

                    if appState.profiles.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text(loc("no_profiles_saved"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        ForEach(appState.profiles) { profile in
                            let active = isProfileActive(profile)
                            let activeMods = profile.extractActiveMods()

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: active ? "folder.fill" : "folder")
                                            .font(.system(size: 18))
                                            .foregroundColor(active ? .accentColor : .secondary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(profile.name)
                                                    .font(.system(size: 14, weight: .bold))

                                                if active {
                                                    StatusBadge(loc("active_badge"), icon: "checkmark.circle")
                                                }

                                                if let ver = profile.factorioVersion, !ver.isEmpty {
                                                    Text("Factorio \(ver)")
                                                        .font(.system(size: 10, design: .monospaced))
                                                        .foregroundColor(.secondary)
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1)
                                                        .background(Color.secondary.opacity(0.12))
                                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                                }
                                            }

                                            Text(String(format: loc("profile_mods_count"), activeMods.count))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    HStack(spacing: 8) {
                                        if !active {
                                            Button(action: {
                                                Task { await appState.activateProfile(profile) }
                                            }) {
                                                Text(loc("activate_profile"))
                                                    .fontWeight(.medium)
                                            }
                                            .buttonStyle(.borderedProminent)
                                        } else {
                                            Button(action: {
                                                appState.updateProfileWithCurrentMods(profile)
                                            }) {
                                                Label("Update", systemImage: "arrow.triangle.2.circlepath")
                                                    .font(.system(size: 12))
                                            }
                                            .buttonStyle(.bordered)
                                            .help("Update this profile with the current mod setup")
                                        }

                                        Button(action: {
                                            profileToDelete = profile
                                            showDeleteConfirmation = true
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .help(loc("delete_profile"))
                                    }
                                }

                                if !activeMods.isEmpty {
                                    Divider()
                                    // Flow of active mod chips
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 180), spacing: 6)], alignment: .leading, spacing: 6) {
                                        ForEach(Array(activeMods.sorted()), id: \.self) { modName in
                                            let isInstalled = appState.installedModsMap[modName] != nil
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(isInstalled ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.4))
                                                    .frame(width: 5, height: 5)
                                                Text(modName)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(isInstalled ? .primary : .secondary)
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(active ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            appState.loadProfiles()
        }
        .confirmationDialog(
            "Delete Profile?",
            isPresented: $showDeleteConfirmation,
            presenting: profileToDelete
        ) { prof in
            Button(loc("delete_profile"), role: .destructive) {
                appState.deleteProfile(prof)
            }
            Button(loc("cancel"), role: .cancel) {}
        } message: { prof in
            Text("Are you sure you want to delete profile '\(prof.name)'?")
        }
    }
}
