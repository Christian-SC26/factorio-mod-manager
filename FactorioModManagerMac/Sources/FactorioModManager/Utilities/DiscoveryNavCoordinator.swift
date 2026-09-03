import AppKit
import Foundation
import SwiftUI

@MainActor
public final class DiscoveryNavCoordinator: ObservableObject {
    @Published public var focusedIndex: Int = 0
    @Published public var selectedModNames: Set<String> = []

    private var keyMonitor: Any?
    private weak var appState: AppState?
    public let targetTab: SidebarTab
    private var getItemNames: (() -> [String])?
    private var onFocusSearch: (() -> Void)?

    public init(targetTab: SidebarTab) {
        self.targetTab = targetTab
    }

    public func start(
        appState: AppState,
        getItemNames: @escaping () -> [String],
        onFocusSearch: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.getItemNames = getItemNames
        self.onFocusSearch = onFocusSearch
        stop()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handleKeyDown(event)
        }
    }

    public func stop() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    public func clampIndex(count: Int) {
        if count == 0 {
            focusedIndex = 0
        } else if focusedIndex >= count {
            focusedIndex = max(0, count - 1)
        }
    }

    public func toggleSelect(name: String) {
        if selectedModNames.contains(name) {
            selectedModNames.remove(name)
        } else {
            selectedModNames.insert(name)
        }
    }

    public func toggleSelectAll(items: [String]) {
        if selectedModNames.count == items.count {
            selectedModNames.removeAll()
        } else {
            selectedModNames = Set(items)
        }
    }

    public func installSelected(appState: AppState) {
        guard !selectedModNames.isEmpty else { return }
        let targets = Array(selectedModNames)
        selectedModNames.removeAll()
        Task {
            await appState.resolveAndInstall(targets: targets)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let appState = appState, appState.selectedTab == targetTab else { return event }

        // Ignore if any modal/sheet or dependency resolving overlay is active
        guard !appState.isDetailSheetPresented &&
              !appState.isResolutionModalPresented &&
              !appState.isKeyboardShortcutsSheetPresented &&
              !appState.isResolving else {
            return event
        }

        // If user is typing in a text field / search box
        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView, textView.isFieldEditor {
            if KeyCodeHelper.isEscape(event) {
                NSApp.keyWindow?.makeFirstResponder(nil)
                return nil
            }
            if event.keyCode == KeyCodeHelper.kVK_DownArrow {
                NSApp.keyWindow?.makeFirstResponder(nil)
                let items = getItemNames?() ?? []
                if !items.isEmpty {
                    focusedIndex = 0
                }
                return nil
            }
            return event
        }

        // Shortcut to focus search: Cmd+F or '/'
        if KeyCodeHelper.isSearch(event) {
            if let onFocusSearch = onFocusSearch {
                onFocusSearch()
                return nil
            }
        }

        let items = getItemNames?() ?? []
        guard !items.isEmpty else { return event }

        // Cmd+A: Select all / Deselect all
        if KeyCodeHelper.isSelectAll(event) {
            toggleSelectAll(items: items)
            return nil
        }

        // Escape: Clear selection if any
        if KeyCodeHelper.isEscape(event) {
            if !selectedModNames.isEmpty {
                selectedModNames.removeAll()
                return nil
            }
        }

        // Down / 'j'
        if KeyCodeHelper.isDown(event) {
            if focusedIndex < items.count - 1 {
                focusedIndex += 1
            }
            return nil
        }

        // Up / 'k'
        if KeyCodeHelper.isUp(event) {
            if focusedIndex > 0 {
                focusedIndex -= 1
            }
            return nil
        }

        // 'x': Toggle selection checkbox
        if KeyCodeHelper.isSelectToggle(event) {
            let clamped = max(0, min(focusedIndex, items.count - 1))
            toggleSelect(name: items[clamped])
            return nil
        }

        // Space: Install selected (or focused)
        if KeyCodeHelper.isSpace(event) {
            if !selectedModNames.isEmpty {
                installSelected(appState: appState)
            } else {
                let clamped = max(0, min(focusedIndex, items.count - 1))
                let currentName = items[clamped]
                if appState.installedModsMap[currentName] == nil {
                    Task {
                        await appState.resolveAndInstall(targets: [currentName])
                    }
                }
            }
            return nil
        }

        // Return / 'i': Open details
        if KeyCodeHelper.isDetails(event) {
            let clamped = max(0, min(focusedIndex, items.count - 1))
            let currentName = items[clamped]
            appState.openModDetails(for: currentName)
            return nil
        }

        return event
    }
}
