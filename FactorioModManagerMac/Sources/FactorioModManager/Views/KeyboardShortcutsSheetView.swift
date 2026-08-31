import SwiftUI
import AppKit

public struct KeyboardShortcutsSheetView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var locMgr = LocalizationManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var filterQuery: String = ""

    struct ShortcutEntry: Identifiable {
        let id = UUID()
        let keys: [String]
        let description: String
        let category: String
    }

    private var shortcuts: [ShortcutEntry] {
        let isRu = locMgr.language == .ru
        return [
            // Global & App
            ShortcutEntry(
                keys: ["⌥", "O"],
                description: isRu ? "Запустить Factorio" : "Launch Factorio game",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),
            ShortcutEntry(
                keys: ["⌘", ","],
                description: isRu ? "Настройки приложения" : "Preferences / Settings",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),
            ShortcutEntry(
                keys: ["⌘", "R"],
                description: isRu ? "Обновить список модов" : "Refresh installed mods",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),
            ShortcutEntry(
                keys: ["⌘", "U"],
                description: isRu ? "Проверить обновления" : "Check for updates",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),
            ShortcutEntry(
                keys: ["⌘", "N"],
                description: isRu ? "Установить моды по URL или имени" : "Install mods from URL/name",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),
            ShortcutEntry(
                keys: ["⌘", "⇧", "I"],
                description: isRu ? "Импортировать файл модпака" : "Import modpack file",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),
            ShortcutEntry(
                keys: ["⌘", "⇧", "E"],
                description: isRu ? "Экспортировать текущий модпак" : "Export current modpack",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),
            ShortcutEntry(
                keys: ["⌘", "⇧", "O"],
                description: isRu ? "Открыть папку mods в Finder" : "Open mods folder in Finder",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),
            ShortcutEntry(
                keys: ["⌘", "⇧", "L"],
                description: isRu ? "Переключить язык (EN / RU)" : "Switch language (EN / RU)",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),
            ShortcutEntry(
                keys: ["⌘", "/"],
                description: isRu ? "Окно горячих клавиш" : "Keyboard shortcuts cheat sheet",
                category: isRu ? "Глобальные и запуск" : "Global & App"
            ),

            // Table Navigation & Management
            ShortcutEntry(
                keys: ["⌘", "F"],
                description: isRu ? "Фокус на строке поиска модов" : "Focus search bar",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["Esc"],
                description: isRu ? "Очистить поиск и вернуть фокус на таблицу" : "Clear search and return to table",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["↓", "или", "J"],
                description: isRu ? "Перейти к следующему моду" : "Navigate to next mod row",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["↑", "или", "K"],
                description: isRu ? "Перейти к предыдущему моду" : "Navigate to previous mod row",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["⇧", "↓", "/", "J"],
                description: isRu ? "Выделить диапазон модов вниз" : "Extend selection downwards",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["⇧", "↑", "/", "K"],
                description: isRu ? "Выделить диапазон модов вверх" : "Extend selection upwards",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["Space"],
                description: isRu ? "Включить / выключить выбранный мод(ы)" : "Toggle selected mod(s) enabled/disabled",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["⌘", "I"],
                description: isRu ? "Открыть окно информации о моде" : "Open mod info / dependencies modal",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["⌘", "⌫"],
                description: isRu ? "Удалить выбранный мод(ы)" : "Delete selected mod(s)",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["⌘", "L"],
                description: isRu ? "Открыть страницу мода на Factorio Portal" : "Open mod page on Factorio Portal",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["⌘", "O"],
                description: isRu ? "Показать файл мода в Finder" : "Reveal mod zip/folder in Finder",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            ),
            ShortcutEntry(
                keys: ["⌘", "A"],
                description: isRu ? "Показать все моды автора (в таблице) / Выделить все" : "Filter by author / Select all",
                category: isRu ? "Таблица модов" : "Mod Table & Navigation"
            )
        ]
    }

    private var groupedShortcuts: [(category: String, items: [ShortcutEntry])] {
        let q = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = shortcuts.filter { entry in
            if q.isEmpty { return true }
            return entry.description.lowercased().contains(q) ||
                   entry.keys.joined(separator: " ").lowercased().contains(q) ||
                   entry.category.lowercased().contains(q)
        }

        var categories: [String] = []
        for item in filtered {
            if !categories.contains(item.category) {
                categories.append(item.category)
            }
        }

        return categories.map { cat in
            (category: cat, items: filtered.filter { $0.category == cat })
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(locMgr.language == .ru ? "Горячие клавиши" : "Keyboard Shortcuts")
                        .font(.title2.bold())
                    Text(locMgr.language == .ru ? "Полный справочник быстрых клавиш Factorio Mod Manager" : "Comprehensive Factorio Mod Manager shortcuts guide")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Search filter
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(locMgr.language == .ru ? "Поиск горячих клавиш..." : "Filter shortcuts...", text: $filterQuery)
                    .textFieldStyle(.plain)

                if !filterQuery.isEmpty {
                    Button(action: { filterQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groupedShortcuts, id: \.category) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.category.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 1) {
                                ForEach(group.items) { item in
                                    HStack {
                                        Text(item.description)
                                            .font(.system(size: 13))
                                            .foregroundColor(.primary)

                                        Spacer()

                                        HStack(spacing: 4) {
                                            ForEach(Array(item.keys.enumerated()), id: \.offset) { _, key in
                                                Text(key)
                                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color.secondary.opacity(0.12))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }

            Divider()

            // Footer
            HStack {
                Text(locMgr.language == .ru ? "Нажмите Esc чтобы закрыть" : "Press Esc or click Close")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(locMgr.language == .ru ? "Закрыть" : "Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 560, minHeight: 480)
    }
}
