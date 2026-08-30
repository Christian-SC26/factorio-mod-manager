import SwiftUI

public struct ProfilesView: View {
    @ObservedObject var appState: AppState
    @State private var newProfileName: String = ""
    @State private var profileToDelete: Profile? = nil
    @State private var showDeleteConfirmation: Bool = false

    private var currentActiveModNames: Set<String> {
        Set(appState.installedMods.filter { $0.enabled && $0.name != "base" }.map { $0.name })
    }

    private func isProfileActive(_ profile: Profile) -> Bool {
        profile.extractActiveMods() == currentActiveModNames
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
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Profiles List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Saved Profiles (\(appState.profiles.count))")
                        .font(.headline)

                    if appState.profiles.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.gearshape")
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
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(active ? .green : .purple)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(profile.name)
                                                    .font(.system(size: 15, weight: .bold))

                                                if active {
                                                    StatusBadge(loc("active_badge"), color: .green, icon: "checkmark.circle.fill")
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
                                                    .fontWeight(.semibold)
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }

                                        Button(action: {
                                            profileToDelete = profile
                                            showDeleteConfirmation = true
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red.opacity(0.8))
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
                                                    .fill(isInstalled ? Color.green : Color.red)
                                                    .frame(width: 6, height: 6)
                                                Text(modName)
                                                    .font(.system(size: 11))
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
                            .background(active ? Color.green.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(active ? Color.green.opacity(0.3) : Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
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
