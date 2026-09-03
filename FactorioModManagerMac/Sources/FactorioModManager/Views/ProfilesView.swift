import SwiftUI

public struct ProfilesView: View {
    @ObservedObject var appState: AppState
    @State private var newProfileName: String = ""
    @State private var profileFilterText: String = ""
    @State private var profileToDelete: Profile? = nil
    @State private var showDeleteConfirmation: Bool = false
    @FocusState private var isFilterFocused: Bool

    private var currentActiveModNames: Set<String> {
        Set(appState.installedMods.filter { appState.isModEnabled($0.name) && $0.name != FactorioConstants.baseModName }.map(\.name))
    }

    private func isProfileActive(_ profile: Profile) -> Bool {
        profile.isMatchingActiveMods(currentActiveModNames)
    }

    private var filteredProfiles: [Profile] {
        let clean = profileFilterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.isEmpty {
            return appState.profiles
        }
        return appState.profiles.filter { $0.name.lowercased().contains(clean) }
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
                    HStack {
                        Text("Saved Profiles (\(filteredProfiles.count))")
                            .font(.headline)

                        Spacer()

                        if !appState.profiles.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Filter profiles...", text: $profileFilterText)
                                    .textFieldStyle(.plain)
                                    .focused($isFilterFocused)
                                    .frame(maxWidth: 180)

                                if !profileFilterText.isEmpty {
                                    Button(action: { profileFilterText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }

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
                    } else if filteredProfiles.isEmpty {
                        VStack(spacing: 8) {
                            Text("No profiles match '\(profileFilterText)'")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Clear Filter") { profileFilterText = "" }
                                .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(filteredProfiles) { profile in
                                ProfileCardView(
                                    profile: profile,
                                    isActive: isProfileActive(profile),
                                    activeMods: profile.extractActiveMods().sorted(),
                                    installedModsMap: appState.installedModsMap,
                                    onActivate: {
                                        Task { await appState.activateProfile(profile) }
                                    },
                                    onUpdate: {
                                        appState.updateProfileWithCurrentMods(profile)
                                    },
                                    onDelete: {
                                        profileToDelete = profile
                                        showDeleteConfirmation = true
                                    },
                                    onRevealInFinder: {
                                        appState.revealProfileInFinder(profile)
                                    }
                                )
                            }
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
        .onReceive(NotificationCenter.default.publisher(for: .focusModSearch)) { _ in
            isFilterFocused = true
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

struct ProfileCardView: View {
    let profile: Profile
    let isActive: Bool
    let activeMods: [String]
    let installedModsMap: [String: [LocalMod]]
    let onActivate: () -> Void
    let onUpdate: () -> Void
    let onDelete: () -> Void
    let onRevealInFinder: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Button(action: onRevealInFinder) {
                        Image(systemName: isActive ? "folder.fill" : "folder")
                            .font(.system(size: 20))
                            .foregroundColor(isActive ? .green : .accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal profile in Finder")

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(profile.name)
                                .font(.system(size: 14, weight: .bold))

                            if isActive {
                                StatusBadge(loc("active_badge"), color: .green, icon: "checkmark.circle.fill")
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
                            .foregroundColor(isActive ? .green.opacity(0.8) : .secondary)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    if !isActive {
                        Button(action: onActivate) {
                            Text(loc("activate_profile"))
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(loc("active_badge"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())

                        Button(action: onUpdate) {
                            Label("Update", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .help("Update this profile with current active mods")
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(loc("delete_profile"))
                }
            }

            if !activeMods.isEmpty {
                Divider()

                let displayedMods = isExpanded ? activeMods : Array(activeMods.prefix(18))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 180), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(displayedMods, id: \.self) { modName in
                        let isInstalled = installedModsMap[modName] != nil
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isActive ? (isInstalled ? Color.green : Color.secondary.opacity(0.4)) : (isInstalled ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.4)))
                                .frame(width: 5, height: 5)
                            Text(modName)
                                .font(.system(size: 11))
                                .foregroundColor(isInstalled ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isActive ? Color.green.opacity(0.08) : Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }

                if activeMods.count > 18 {
                    Button(action: { isExpanded.toggle() }) {
                        Text(isExpanded ? "Show less" : "Show all \(activeMods.count) mods (\(activeMods.count - 18) more)...")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(isActive ? Color.green.opacity(0.04) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? Color.green.opacity(0.6) : Color.secondary.opacity(0.15), lineWidth: isActive ? 1.5 : 1)
        )
    }
}
