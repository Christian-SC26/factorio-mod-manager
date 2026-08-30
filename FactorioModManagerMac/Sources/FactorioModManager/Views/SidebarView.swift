import SwiftUI

public struct SidebarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var locMgr = LocalizationManager.shared

    public var body: some View {
        List(selection: $appState.selectedTab) {
            Section(header: Text("MOD MANAGEMENT")) {
                NavigationLink(value: SidebarTab.installed) {
                    Label {
                        HStack {
                            Text(loc("sidebar_mods"))
                            Spacer()
                            if !appState.installedMods.isEmpty {
                                Text("\(appState.installedMods.count)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.accentColor)
                    }
                }

                NavigationLink(value: SidebarTab.install) {
                    Label(loc("sidebar_install"), systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.primary)
                }

                NavigationLink(value: SidebarTab.updates) {
                    Label {
                        HStack {
                            Text(loc("sidebar_updates"))
                            Spacer()
                            if !appState.updatesAvailable.isEmpty {
                                Text("\(appState.updatesAvailable.count)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }

            Section(header: Text("PROFILES & EXPORT")) {
                NavigationLink(value: SidebarTab.profiles) {
                    Label {
                        HStack {
                            Text(loc("sidebar_profiles"))
                            Spacer()
                            if !appState.profiles.isEmpty {
                                Text("\(appState.profiles.count)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundColor(.purple)
                    }
                }

                NavigationLink(value: SidebarTab.exportImport) {
                    Label(loc("sidebar_export_import"), systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                        .foregroundColor(.primary)
                }
            }

            Section(header: Text("DISCOVERY")) {
                NavigationLink(value: SidebarTab.search) {
                    Label(loc("sidebar_search"), systemImage: "magnifyingglass")
                        .foregroundColor(.blue)
                }

                NavigationLink(value: SidebarTab.authors) {
                    Label(loc("sidebar_authors"), systemImage: "person.2.fill")
                        .foregroundColor(.indigo)
                }

                NavigationLink(value: SidebarTab.optional) {
                    Label(loc("sidebar_optional"), systemImage: "puzzlepiece.fill")
                        .foregroundColor(.yellow)
                }
            }

            Section(header: Text("PREFERENCES")) {
                NavigationLink(value: SidebarTab.settings) {
                    Label(loc("sidebar_settings"), systemImage: "gearshape.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }
}
