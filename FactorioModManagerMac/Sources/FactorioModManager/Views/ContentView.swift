import SwiftUI
import AppKit

public struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var locMgr = LocalizationManager.shared

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
        } detail: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    switch appState.selectedTab {
                    case .installed:
                        InstalledModsView(appState: appState)
                    case .install:
                        InstallModsView(appState: appState)
                    case .updates:
                        UpdatesView(appState: appState)
                    case .profiles:
                        ProfilesView(appState: appState)
                    case .search:
                        SearchPortalView(appState: appState)
                    case .authors:
                        AuthorBrowseView(appState: appState)
                    case .optional:
                        OptionalModsView(appState: appState)
                    case .exportImport:
                        ExportImportView(appState: appState)
                    case .settings:
                        SettingsView(appState: appState)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Notification Toast Overlay
                if let notif = appState.currentNotification {
                    HStack(spacing: 10) {
                        Image(systemName: notif.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(notif.isError ? .red : .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notif.title)
                                .font(.system(size: 13, weight: .bold))
                            Text(notif.message)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { appState.currentNotification = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .frame(maxWidth: 360)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation {
                                if appState.currentNotification?.id == notif.id {
                                    appState.currentNotification = nil
                                }
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Factorio version badge
                HStack(spacing: 4) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 10))
                    Text("Factorio \(appState.effectiveFactorioVersion)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

                // Language toggle button
                Button(action: {
                    locMgr.toggleLanguage()
                }) {
                    Text(locMgr.language == .en ? "RU" : "EN")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .frame(width: 26, height: 18)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .help("Switch Language / Сменить язык")

                // Open mods folder
                Button(action: {
                    NSWorkspace.shared.open(appState.modsDirectory)
                }) {
                    Image(systemName: "folder")
                }
                .help(loc("open_mods_folder"))

                // Refresh button
                Button(action: {
                    appState.refreshAll()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh installed mods")
            }
        }
        .sheet(isPresented: $appState.isResolutionModalPresented) {
            ResolutionSheetView(appState: appState)
        }
        .sheet(isPresented: $appState.isDetailSheetPresented) {
            ModDetailSheet(appState: appState)
        }
        .frame(minWidth: 860, minHeight: 560)
    }
}
