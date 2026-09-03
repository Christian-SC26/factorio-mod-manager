import Foundation
import SwiftUI

extension AppState {
    public func loadProfiles() {
        self.profiles = modListMgr.listProfiles()
    }

    public func saveCurrentProfile(name: String) {
        do {
            let versions = Dictionary(uniqueKeysWithValues: self.installedMods.map { ($0.name, $0.version.raw) })
            _ = try modListMgr.saveProfile(name: name, states: self.modStates, knownVersions: versions)
            loadProfiles()
            showNotification(title: loc("profiles_title"), message: loc("profile_saved", name))
            objectWillChange.send()
        } catch {
            showNotification(title: loc("profiles_title"), message: error.localizedDescription, isError: true)
        }
    }

    public func updateProfileWithCurrentMods(_ profile: Profile) {
        do {
            let versions = Dictionary(uniqueKeysWithValues: self.installedMods.map { ($0.name, $0.version.raw) })
            _ = try modListMgr.saveProfile(name: profile.name, states: self.modStates, knownVersions: versions)
            loadProfiles()
            showNotification(title: loc("profiles_title"), message: loc("profile_updated", profile.name))
            objectWillChange.send()
        } catch {
            showNotification(title: loc("profiles_title"), message: error.localizedDescription, isError: true)
        }
    }

    public func activateProfile(_ profile: Profile) async {
        let (success, _, missing) = modListMgr.loadProfile(name: profile.name)
        if success {
            loadInstalledMods()
            objectWillChange.send()
            if missing.isEmpty {
                showNotification(title: loc("profiles_title"), message: loc("profile_activated", profile.name))
            } else {
                showNotification(title: loc("profiles_title"), message: loc("profile_missing_mods_resolving", missing.count))
                await resolveDependencies(
                    targets: missing,
                    includeRecommended: true,
                    includeOptional: false,
                    forceReinstall: false
                )
            }
        } else {
            showNotification(title: loc("profiles_title"), message: loc("profile_activate_failed", profile.name), isError: true)
        }
    }

    public func deleteProfile(_ profile: Profile) {
        let deleted = modListMgr.deleteProfile(name: profile.name, filename: profile.filename)
        if deleted {
            loadProfiles()
            showNotification(title: loc("profiles_title"), message: loc("profile_deleted", profile.name))
            objectWillChange.send()
        }
    }

    public func revealProfileInFinder(_ profile: Profile) {
        let filename = profile.filename ?? "\(ModListManager.safeProfileFilename(from: profile.name)).json"
        let fileURL = modListMgr.profilesDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else {
            NSWorkspace.shared.open(modListMgr.profilesDirectory)
        }
    }
}
