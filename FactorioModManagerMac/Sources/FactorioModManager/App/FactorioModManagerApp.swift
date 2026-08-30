import SwiftUI
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

@main
struct FactorioModManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var locMgr = LocalizationManager.shared

    var body: some Scene {
        WindowGroup("Factorio Mod Manager") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(locMgr)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1020, height: 680)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("Install Mods...") {
                    appState.selectedTab = .install
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Open Mods Directory") {
                    NSWorkspace.shared.open(appState.modsDirectory)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Import Modpack...") {
                    appState.selectedTab = .exportImport
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Export Modpack...") {
                    appState.selectedTab = .exportImport
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Refresh Mods") {
                    appState.refreshAll()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Check for Updates") {
                    appState.selectedTab = .updates
                    Task { await appState.checkForUpdates() }
                }
                .keyboardShortcut("u", modifiers: .command)

                Divider()

                Button("Switch Language (EN / RU)") {
                    locMgr.toggleLanguage()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView(appState: appState)
                .environmentObject(appState)
                .environmentObject(locMgr)
                .frame(width: 600, height: 480)
        }
    }
}
