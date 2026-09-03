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

                // Notification Toast Overlay (Monochrome)
                if let notif = appState.currentNotification {
                    HStack(spacing: 10) {
                        Image(systemName: notif.isError ? "exclamationmark.circle" : "checkmark.circle")
                            .foregroundColor(.primary)
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
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .frame(maxWidth: 360)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
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
                Button(action: {
                    appState.launchFactorio()
                }) {
                    HStack(spacing: 5) {
                        Text("Run")
                            .font(.system(size: 12, weight: .bold))
                        Text("Factorio \(appState.effectiveFactorioVersion)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .help(loc("launch_factorio_tooltip"))
            }
        }
        .sheet(isPresented: $appState.isResolutionModalPresented) {
            ResolutionSheetView(appState: appState)
        }
        .sheet(isPresented: $appState.isKeyboardShortcutsSheetPresented) {
            KeyboardShortcutsSheetView(appState: appState)
        }
        .overlay {
            if appState.isResolving {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .scaleEffect(1.2)

                        VStack(spacing: 6) {
                            Text(loc("resolving_dependencies_title"))
                                .font(.headline)
                                .foregroundColor(.primary)

                            if !appState.resolvingStatusText.isEmpty {
                                Text(appState.resolvingStatusText)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(28)
                    .frame(minWidth: 280, maxWidth: 400)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                }
                .transition(.opacity)
                .zIndex(200)
            }

            if appState.isDetailSheetPresented {
                GeometryReader { proxy in
                    ZStack {
                        ModalBackdropView {
                            withAnimation(.easeOut(duration: 0.15)) {
                                appState.isDetailSheetPresented = false
                            }
                        }
                        .ignoresSafeArea()

                        ModDetailSheet(appState: appState)
                            .frame(width: min(840, max(580, proxy.size.width - 64)))
                            .frame(height: max(420, proxy.size.height * 0.95))
                            .background(Color(NSColor.windowBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
                            .transition(.scale(scale: 0.97).combined(with: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 860, minHeight: 560)
    }
}
