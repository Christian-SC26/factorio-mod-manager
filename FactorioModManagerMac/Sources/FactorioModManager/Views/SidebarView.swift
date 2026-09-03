import SwiftUI

public struct SidebarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var locMgr = LocalizationManager.shared

    public var body: some View {
        List(selection: $appState.selectedTab) {
            Section(header: Text(loc("sidebar_section_management"))) {
                NavigationLink(value: SidebarTab.installed) {
                    Label {
                        HStack {
                            Text(loc("sidebar_mods"))
                            Spacer()
                            if !appState.installedMods.isEmpty {
                                Text("\(appState.installedMods.count)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "archivebox")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(value: SidebarTab.install) {
                    Label {
                        Text(loc("sidebar_install"))
                    } icon: {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(value: SidebarTab.updates) {
                    Label {
                        HStack {
                            Text(loc("sidebar_updates"))
                            Spacer()
                            if !appState.updatesAvailable.isEmpty {
                                Text("\(appState.updatesAvailable.count)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text(loc("sidebar_section_profiles"))) {
                NavigationLink(value: SidebarTab.profiles) {
                    Label {
                        HStack {
                            Text(loc("sidebar_profiles"))
                            Spacer()
                            if !appState.profiles.isEmpty {
                                Text("\(appState.profiles.count)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(value: SidebarTab.exportImport) {
                    Label {
                        Text(loc("sidebar_export_import"))
                    } icon: {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text(loc("sidebar_section_discovery"))) {
                NavigationLink(value: SidebarTab.search) {
                    Label {
                        Text(loc("sidebar_search"))
                    } icon: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(value: SidebarTab.authors) {
                    Label {
                        Text(loc("sidebar_authors"))
                    } icon: {
                        Image(systemName: "person.2")
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink(value: SidebarTab.optional) {
                    Label {
                        Text(loc("sidebar_optional"))
                    } icon: {
                        Image(systemName: "puzzlepiece")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text(loc("sidebar_section_preferences"))) {
                NavigationLink(value: SidebarTab.settings) {
                    Label {
                        Text(loc("sidebar_settings"))
                    } icon: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }
}
