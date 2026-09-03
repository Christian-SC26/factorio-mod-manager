import Foundation
import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case en = "en"
    case ru = "ru"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        }
    }
}

public final class LocalizationManager: ObservableObject, @unchecked Sendable {
    public static let shared = LocalizationManager()

    private let lock = NSLock()
    private var currentLangValue: AppLanguage = .en

    @Published public var language: AppLanguage = .en

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? ""
        if let lang = AppLanguage(rawValue: saved) {
            self.currentLangValue = lang
            self.language = lang
        } else {
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            if preferred.contains("ru") || preferred.contains("russian") {
                self.currentLangValue = .ru
                self.language = .ru
            } else {
                self.currentLangValue = .en
                self.language = .en
            }
        }
    }

    public func setLanguage(_ lang: AppLanguage) {
        lock.lock()
        self.currentLangValue = lang
        lock.unlock()
        UserDefaults.standard.set(lang.rawValue, forKey: "app_language")
        DispatchQueue.main.async {
            self.language = lang
        }
    }

    public func toggleLanguage() {
        setLanguage(currentLang == .en ? .ru : .en)
    }

    public var currentLang: AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return currentLangValue
    }

    public func localized(_ key: String, _ args: [CVarArg] = []) -> String {
        let lang = currentLang
        let dict = LocalizationManager.strings[lang] ?? LocalizationManager.strings[.en]!
        let format = dict[key] ?? LocalizationManager.strings[.en]?[key] ?? key
        if args.isEmpty {
            return format
        }
        return String(format: format, arguments: args)
    }

    private static let strings: [AppLanguage: [String: String]] = [
        .en: [
            "app_name": "Factorio Mod Manager",
            "tagline": "Fast, native mod manager with dependency resolution and mirror downloads",
            "sidebar_mods": "Installed Mods",
            "sidebar_install": "Install Mods",
            "sidebar_updates": "Updates",
            "sidebar_profiles": "Profiles",
            "sidebar_search": "Search Portal",
            "sidebar_authors": "Browse by Author",
            "sidebar_optional": "Optional Mods",
            "sidebar_export_import": "Export & Import",
            "sidebar_settings": "Settings",
            
            // Installed Mods View
            "installed_title": "Installed Mods",
            "filter_all": "All",
            "filter_enabled": "Enabled",
            "filter_disabled": "Disabled",
            "search_mods_placeholder": "Filter installed mods...",
            "sort_by": "Sort by",
            "sort_name": "Name",
            "sort_version": "Version",
            "sort_size": "Size",
            "sort_status": "Status",
            "sort_date": "Date Added",
            "total_mods_summary": "%d mods (%d enabled, %d disabled)",
            "enable_all": "Enable All",
            "disable_all": "Disable All",
            "delete_selected": "Delete Selected",
            "confirm_delete_title": "Delete Mod?",
            "confirm_delete_message": "Are you sure you want to delete '%@'? This will remove the mod archive from disk.",
            "confirm_delete_multiple": "Are you sure you want to delete %d selected mods? This cannot be undone.",
            "reveal_in_finder": "Reveal in Finder",
            "open_mods_folder": "Open Mods Folder",
            "check_updates": "Check Updates",
            "no_mods_installed": "No mods installed yet",
            "no_mods_installed_desc": "Install mods by URL, search the online portal, or import a modpack.",
            "installed_status": "Installed",
            "enabled_status": "Enabled",
            "disabled_status": "Disabled",
            "size_label": "Size:",
            
            // Install Mods View
            "install_title": "Install Mods",
            "install_input_placeholder": "Paste mod URLs or names (space or newline separated, e.g. 'flib space-exploration https://mods.factorio.com/mod/Krastorio2')...",
            "include_recommended": "Download recommended dependencies (+)",
            "include_optional": "Download optional dependencies (?)",
            "force_reinstall": "Force reinstall if already installed",
            "clean_old_versions": "Automatically remove older versions",
            "resolve_and_preview": "Resolve Dependencies",
            "resolving_dependencies": "Resolving dependencies from mirror...",
            "resolution_plan_title": "Installation Plan",
            "mods_to_download_section": "To Download & Install (%d)",
            "mods_up_to_date_section": "Up to date (%d)",
            "conflicts_section": "Conflicts Detected",
            "missing_section": "Missing / Not Found",
            "warnings_section": "Warnings",
            "dependency_tree": "Dependency Tree",
            "start_download": "Start Download",
            "cancel": "Cancel",
            "downloading_mods": "Downloading mods...",
            "all_mods_up_to_date": "All specified mods and their dependencies are already installed and up to date!",
            "download_success": "Successfully downloaded and enabled %d mod(s)!",
            "download_failed": "Download completed with errors: %d succeeded, %d failed.",

            // Updates View
            "updates_title": "Mod Updates",
            "checking_for_updates": "Checking for updates...",
            "no_updates_available": "All installed mods are up to date!",
            "update_all": "Update All (%d)",
            "update_single": "Update",
            "updating_mods": "Updating mods...",
            "update_available_badge": "Update Available",
            "current_ver": "Current",
            "new_ver": "New",

            // Profiles View
            "profiles_title": "Modpack Profiles",
            "profiles_desc": "Switch whole mod setups (e.g. Space Age, Krastorio 2, Pyanodons) in 0.01s.",
            "save_current_profile": "Save Current Setup as Profile",
            "profile_name_placeholder": "Profile name (e.g. space-age)",
            "save_button": "Save Profile",
            "profile_saved": "Profile '%@' saved successfully",
            "activate_profile": "Activate Profile",
            "active_badge": "ACTIVE",
            "delete_profile": "Delete",
            "profile_mods_count": "%d active mods",
            "missing_mods_warning": "Warning: %d mods in this profile are missing on disk.",
            "download_missing_button": "Download Missing Mods",
            "no_profiles_saved": "No profiles saved yet.",

            // Error Messages
            "error_empty_mod_name": "Mod name cannot be empty",
            "error_mod_not_found": "Mod '%@' not found on portal",
            "error_corrupted_data": "Corrupted or invalid metadata for '%@'",
            "error_invalid_download_url": "Invalid download URL: %@",
            "error_destination_file_creation": "Failed to create destination file at '%@'",
            "error_invalid_zip": "'%@' is not a valid ZIP archive",
            "error_empty_profile_name": "Profile name cannot be empty",
            "error_file_not_found": "File not found at '%@'",

            // Search Portal View
            "search_portal_title": "Search Mod Portal",
            "search_input_placeholder": "Search mods by keyword, title, or description (e.g. train, solar, space)...",
            "search_button": "Search",
            "scope_all": "All Versions",
            "scope_v2": "Factorio 2.x only",
            "scope_local": "Installed Mods",
            "searching": "Searching portal...",
            "no_search_results": "No mods found matching '%@'.",
            "downloads_count_badge": "%@ downloads",
            "deprecated_badge": "Deprecated",
            "install_button": "Install",

            // Author Browse View
            "author_title": "Browse by Author",
            "author_input_placeholder": "Author username or profile URL (e.g. Earendel, Bilka, Raiguard)...",
            "fetch_author_button": "Browse Mods",
            "fetching_author": "Fetching author mods...",
            "author_summary": "%d mods by %@ (%d active, %d deprecated)",
            "install_selected": "Install Selected (%d)",

            // Optional Mods View
            "optional_title": "Optional Mod Recommendations",
            "optional_desc": "Browse and install optional add-on mods recommended by your currently installed mods.",
            "scan_optional_button": "Scan for Optional Mods",
            "scanning_optional": "Scanning installed mods...",
            "no_optional_found": "No missing optional mods found. All recommendations are already installed.",
            "suggested_by": "Suggested by:",

            // Export & Import View
            "export_import_title": "Export & Import Modpacks",
            "export_section_title": "Export Current Modpack",
            "export_section_desc": "Save your active mod list to share with friends or backup your setup.",
            "export_json_button": "Export to JSON File",
            "export_txt_button": "Export to Links List (.txt)",
            "import_section_title": "Import Modpack",
            "import_section_desc": "Select a modpack file (.json or .txt) to automatically download and activate all required mods.",
            "import_file_button": "Select File to Import...",
            "exported_success": "Successfully exported %d mods to '%@'!",
            "imported_success": "Loaded %d mods from '%@'. Starting dependency resolution...",

            // Settings View
            "settings_title": "Settings",
            "mods_directory_title": "Factorio Mods Directory",
            "select_folder": "Choose Folder...",
            "reset_default": "Reset to Default",
            "factorio_version_title": "Target Factorio Version",
            "auto_detect_label": "Auto-detect (Detected: %@)",
            "clean_old_title": "Auto-clean old mod versions",
            "clean_old_desc": "Automatically deletes previous zip files of updated mods.",
            "auto_enable_title": "Auto-enable installed mods",
            "auto_enable_desc": "Immediately activates newly downloaded mods in mod-list.json.",
            "language_title": "Interface Language",
            "about_title": "About Factorio Mod Manager",
            "version_label": "Version 2.1",
            "mirror_info": "Downloads and resolves mods using mirror-factorio.eu (no Steam login required).",

            // Mod Details
            "mod_details_title": "Mod Details",
            "description_label": "Description",
            "author_label": "Author:",
            "category_label": "Category:",
            "factorio_ver_label": "Factorio Version:",
            "latest_release_label": "Latest Release:",
            "download_url_label": "Download Link:",
            "dependencies_label": "Dependencies (%d)",
            "dep_required": "Required",
            "dep_recommended": "Recommended (+)",
            "dep_optional": "Optional (?)",
            "dep_conflict": "Incompatible (!)",
            "close_button": "Close",
            "open_on_portal": "Open on Factorio Portal",

            // Search Portal View additions
            "filter_2_1_recent": "2.1 (Recent)",
            "filter_2_1_all": "2.1 (All)",
            "filter_2_0": "Factorio 2.0",
            "search_results_by_date": "%d mods (by update date)",
            "loading_catalog": "Loading Factorio %@ mods catalog...",
            "details_button": "Details",
            "installed_button": "Installed",

            // Installation Plan & Resolution additions
            "installation_plan_summary": "%d to download, %d up to date",
            "download_completed_installed": "Installed",
            "enable_all_mods": "Enable All (%d) Mods",
            "current_version_label": "(current: v%@)",
            "status_update": "Update",
            "status_new": "New",

            // Profiles additions
            "filter_profiles_placeholder": "Filter profiles...",
            "saved_profiles_count": "Saved Profiles (%d)",
            "save_profile_caption": "Saves all currently active mods (%d) into a new profile.",
            "no_profiles_match": "No profiles match '%@'",
            "clear_filter": "Clear Filter",
            "delete_profile_title": "Delete Profile?",

            // Updates additions
            "updates_subtitle_checked": "All installed mods are checked against latest releases.",
            "updates_subtitle_count": "%d updates available for installed mods.",
            "filter_updates_placeholder": "Filter updates...",
            "target_factorio_branch": "Target Factorio branch: %@",
            "updating_count_inplace": "Updating %d/%d...",
            "checking_updates_count": "Checking %d/%d...",

            // Install Mods additions
            "install_desc": "Install mods directly from mirror with full automatic recursive dependency resolution.",
            "mod_urls_or_names": "Mod URLs or Names:",
            "popular_presets": "Popular:",
            "clear_button": "Clear",
            "dependency_options_title": "Dependency & Download Options",

            // Sidebar additions
            "sidebar_section_management": "MOD MANAGEMENT",
            "sidebar_section_profiles": "PROFILES & EXPORT",
            "sidebar_section_discovery": "DISCOVERY",
            "sidebar_section_preferences": "PREFERENCES",

            // Notifications & actions additions
            "mod_removed": "Mod '%@' removed.",
            "mods_removed_count": "%d mods removed.",
            "mods_removed_and_dependents_disabled": "Removed %d mod(s) and disabled %d dependent mod(s).",
            "profile_updated": "Profile '%@' updated with current mod configuration.",
            "profile_activated": "Profile '%@' activated successfully!",
            "profile_missing_mods_resolving": "%d mods from profile missing on disk. Resolving...",
            "profile_activate_failed": "Failed to activate profile '%@'.",
            "profile_deleted": "Profile '%@' deleted.",

            // Profiles View additions
            "show_less": "Show less",
            "show_all_mods_count": "Show all %d mods (%d more)...",
            "update_profile_help": "Update this profile with current active mods",
            "delete_profile_confirm_message": "Are you sure you want to delete profile '%@'?",

            // Export / Import additions
            "export_import_desc": "Share your mod setups with friends or restore saved modpacks across machines.",
            "active_mods_ready_for_export": "Current active mods ready for export: %d",
            "no_mods_in_import_file": "No mod entries found in selected file.",

            // Author Browse additions
            "popular_authors": "Popular Authors:",
            "author_browse_desc": "Enter a mod author's username or portal URL to explore and install their mods.",
            "author_not_found": "Author '%@' not found or has no published mods.",
            "select_all": "Select All",
            "deselect_all": "Deselect All",

            // Optional Mods additions
            "install_all_count": "Install All (%d)",
            "optional_mods_empty_desc": "Click the button below to scan your installed mods for suggested and optional companion mods.",

            // Settings additions
            "settings_desc": "Configure mods storage directory, target Factorio branch, and manager behavior.",
            "branch_version_picker_label": "Target Branch / Version",
            "factorio_2_1_label": "2.1 (Current Latest)",
            "factorio_2_0_label": "2.0 (Space Age)",
            "custom_version_label": "Custom Version...",
            "custom_version_field_label": "Custom Version:",
            "download_management_rules_title": "Download & Management Rules",

            // Native Table View & Installed Mods additions
            "col_active": "Active",
            "col_name": "Mod Name",
            "col_author": "Author",
            "col_date": "Date Added",
            "col_game_ver": "Game Ver",
            "col_version": "Version",
            "col_size": "Size",
            "col_actions": "Actions",
            "official_content_header": "OFFICIAL FACTORIO CONTENT & EXPANSIONS",
            "community_mods_header": "INSTALLED COMMUNITY MODS (%d)",
            "built_in_label": "Built-in",
            "context_mod_details": "Mod Details...",
            "context_open_portal": "Open on Portal",
            "context_toggle_selected": "Toggle Selected Mods",
            "context_disable_mod": "Disable Mod",
            "context_enable_mod": "Enable Mod",
            "context_reveal_finder": "Reveal in Finder",
            "context_delete_multiple": "Delete %d Mods...",
            "context_delete_single": "Delete Mod...",
            "tooltip_open_portal": "Open on Factorio Portal (⌘L)",
            "tooltip_mod_details": "Mod Details (⌘I)",
            "tooltip_reveal_finder": "Reveal in Finder (⌘O)",
            "tooltip_delete_mod": "Delete Mod (⌫)",
            "recheck_updates_tooltip": "Re-check for updates",
            "launch_factorio_tooltip": "Launch Factorio (⌘R)",

            // Installed Mods Menu & Sheets additions
            "profile_active_item": "%@ (Active)",
            "save_current_as_profile_menu": "Save Current as Profile...",
            "manage_profiles_menu": "Manage Profiles...",
            "portal_modpacks_count": "Portal Modpacks (%d)",
            "loading_modpacks_catalog": "Loading modpacks catalog...",
            "no_modpacks_found_for_version": "No modpacks found for Factorio %@",
            "my_saved_modpacks": "My Saved Modpacks",
            "modpack_actions": "Modpack Actions",
            "refresh_modpacks_catalog": "Refresh Modpacks Catalog",
            "import_modpack_file_menu": "Import Modpack File...",
            "export_current_modpack_menu": "Export Current Modpack...",
            "manage_modpacks_menu": "Manage Modpacks...",
            "modpacks_button": "Modpacks",
            "modpacks_button_count": "Modpacks (%d)",
            "save_current_profile_title": "Save Current Profile",
            "dep_conflict_detected": "Dependency Conflict Detected",
            "dep_conflict_desc": "Deleting %d mod(s) will break %d dependent mod(s).",
            "mods_to_be_deleted": "Mods to be deleted:",
            "active_mods_fail_to_load": "Active mods that depend on them and will fail to load:",
            "requires_mod": "requires %@",
            "dep_conflict_recommendation": "Recommended Action: Delete the mod(s) and automatically disable dependent mods so Factorio can launch safely without crashing.",
            "delete_anyway": "Delete Anyway",
            "delete_and_disable_dependents": "Delete & Disable Dependent Mods",

            // Mod Details additions
            "unknown_author": "Unknown",
            "factorio_version_prefix": "Factorio: %@",
            "released_date_prefix": "Released: %@",
            "local_file_section": "Local File",
            "description_tab": "Description",
            "changelog_tab": "Changelog",
            "releases_tab": "Releases & Dependencies",
            "screenshots_title": "Screenshots",
            "no_changelog": "No changelog provided for this mod.",
            "no_full_description": "No detailed description provided.",
        ],
        .ru: [
            "app_name": "Factorio Mod Manager",
            "tagline": "Быстрый нативный менеджер модов с разрешением зависимостей и загрузкой с зеркала",
            "sidebar_mods": "Установленные моды",
            "sidebar_install": "Установка модов",
            "sidebar_updates": "Обновления",
            "sidebar_profiles": "Профили и сборки",
            "sidebar_search": "Поиск на портале",
            "sidebar_authors": "Моды по автору",
            "sidebar_optional": "Опциональные моды",
            "sidebar_export_import": "Экспорт и импорт",
            "sidebar_settings": "Настройки",
            "description_label": "Описание",
            
            // Installed Mods View
            "installed_title": "Установленные моды",
            "filter_all": "Все",
            "filter_enabled": "Включенные",
            "filter_disabled": "Отключенные",
            "search_mods_placeholder": "Фильтр установленных модов...",
            "sort_by": "Сортировка",
            "sort_name": "Имя",
            "sort_version": "Версия",
            "sort_size": "Размер",
            "sort_status": "Статус",
            "sort_date": "Дата добавления",
            "total_mods_summary": "%d модов (%d включено, %d отключено)",
            "enable_all": "Включить все",
            "disable_all": "Отключить все",
            "delete_selected": "Удалить выбранные",
            "confirm_delete_title": "Удалить мод?",
            "confirm_delete_message": "Вы уверены, что хотите удалить '%@'? Архив мода будет удален с диска.",
            "confirm_delete_multiple": "Вы уверены, что хотите удалить %d выбранных модов? Это действие необратимо.",
            "reveal_in_finder": "Показать в Finder",
            "open_mods_folder": "Открыть папку модов",
            "check_updates": "Проверить обновления",
            "no_mods_installed": "Моды не найдены",
            "no_mods_installed_desc": "Установите моды по ссылке, через поиск или импортируйте сборку.",
            "installed_status": "Установлен",
            "enabled_status": "Включен",
            "disabled_status": "Отключен",
            "size_label": "Размер:",
            
            // Install Mods View
            "install_title": "Установка модов",
            "install_input_placeholder": "Вставьте ссылки или имена модов (через пробел или с новой строки, например: flib space-exploration https://mods.factorio.com/mod/Krastorio2)...",
            "include_recommended": "Скачивать рекомендуемые зависимости (+)",
            "include_optional": "Скачивать опциональные зависимости (?)",
            "force_reinstall": "Принудительно переустановить при совпадении версий",
            "clean_old_versions": "Автоматически удалять старые версии",
            "resolve_and_preview": "Разрешить зависимости",
            "resolving_dependencies": "Поиск зависимостей через зеркало...",
            "resolution_plan_title": "План установки",
            "mods_to_download_section": "Будут скачаны и установлены (%d)",
            "mods_up_to_date_section": "Уже актуальны (%d)",
            "conflicts_section": "Обнаружены конфликты",
            "missing_section": "Не найдены на портале",
            "warnings_section": "Предупреждения",
            "dependency_tree": "Дерево зависимостей",
            "start_download": "Начать загрузку",
            "cancel": "Отмена",
            "downloading_mods": "Загрузка модов...",
            "all_mods_up_to_date": "Все указанные моды и их зависимости уже установлены и актуальны!",
            "download_success": "Успешно скачано и активировано %d мод(ов)!",
            "download_failed": "Загрузка завершена с ошибками: %d успешно, %d неудачно.",

            // Updates View
            "updates_title": "Обновления модов",
            "checking_for_updates": "Проверка обновлений...",
            "no_updates_available": "Все установленные моды имеют актуальные версии!",
            "update_all": "Обновить все (%d)",
            "update_single": "Обновить",
            "updating_mods": "Обновление модов...",
            "update_available_badge": "Есть обновление",
            "current_ver": "Текущая",
            "new_ver": "Новая",

            // Profiles View
            "profiles_title": "Профили и сборки",
            "profiles_desc": "Мгновенное переключение между целыми сборками (Space Age, Krastorio 2, Pyanodons) за 0.01 сек.",
            "save_current_profile": "Сохранить текущую сборку как профиль",
            "profile_name_placeholder": "Имя профиля (например space-age)",
            "save_button": "Сохранить профиль",
            "profile_saved": "Профиль '%@' успешно сохранен",
            "activate_profile": "Активировать профиль",
            "active_badge": "АКТИВЕН",
            "delete_profile": "Удалить",
            "profile_mods_count": "%d активных модов",
            "missing_mods_warning": "Внимание: %d модов из этого профиля отсутствуют на диске.",
            "download_missing_button": "Скачать недостающие моды",
            "no_profiles_saved": "Сохраненных профилей пока нет.",

            // Error Messages
            "error_empty_mod_name": "Имя мода не может быть пустым",
            "error_mod_not_found": "Мод '%@' не найден на портале",
            "error_corrupted_data": "Поврежденные или некорректные данные для '%@'",
            "error_invalid_download_url": "Некорректная ссылка на скачивание: %@",
            "error_destination_file_creation": "Не удалось создать целевой файл: %@",
            "error_invalid_zip": "Файл '%@' не является корректным ZIP-архивом",
            "error_empty_profile_name": "Имя профиля не может быть пустым",
            "error_file_not_found": "Файл не найден по пути '%@'",

            // Search Portal View
            "search_portal_title": "Поиск на портале",
            "search_input_placeholder": "Поиск модов по ключевым словам или описанию (например train, solar, space)...",
            "search_button": "Искать",
            "scope_all": "Все версии",
            "scope_v2": "Только Factorio 2.x",
            "scope_local": "Среди установленных",
            "searching": "Поиск на портале...",
            "no_search_results": "По запросу '%@' ничего не найдено.",
            "downloads_count_badge": "%@ загрузок",
            "deprecated_badge": "Устаревший",
            "install_button": "Установить",

            // Author Browse View
            "author_title": "Моды по автору",
            "author_input_placeholder": "Имя автора или ссылка на профиль (например Earendel, Bilka, Raiguard)...",
            "fetch_author_button": "Найти моды",
            "fetching_author": "Загрузка списка модов автора...",
            "author_summary": "%d модов автора %@ (%d активных, %d устаревших)",
            "install_selected": "Скачать выбранные (%d)",

            // Optional Mods View
            "optional_title": "Опциональные моды",
            "optional_desc": "Просмотр и установка рекомендуемых дополнений для установленных у вас модов.",
            "scan_optional_button": "Найти опциональные моды",
            "scanning_optional": "Поиск опциональных зависимостей...",
            "no_optional_found": "Недостающих опциональных модов не найдено. Все рекомендации уже установлены.",
            "suggested_by": "Рекомендован в:",

            // Export & Import View
            "export_import_title": "Экспорт и импорт сборок",
            "export_section_title": "Экспорт текущей сборки",
            "export_section_desc": "Сохраните список активных модов в файл, чтобы поделиться с друзьями или сделать бэкап.",
            "export_json_button": "Экспорт в файл JSON",
            "export_txt_button": "Экспорт списка ссылок (.txt)",
            "import_section_title": "Импорт сборки",
            "import_section_desc": "Выберите файл сборки (.json или .txt) для автоматической загрузки и активации всех модов.",
            "import_file_button": "Выбрать файл для импорта...",
            "exported_success": "Успешно экспортировано %d модов в '%@'!",
            "imported_success": "Загружено %d модов из '%@'. Запуск разрешения зависимостей...",

            // Settings View
            "settings_title": "Настройки",
            "mods_directory_title": "Папка модов Factorio",
            "select_folder": "Выбрать папку...",
            "reset_default": "По умолчанию",
            "factorio_version_title": "Целевая версия Factorio",
            "auto_detect_label": "Автоопределение (Обнаружено: %@)",
            "clean_old_title": "Удалять старые версии при обновлении",
            "clean_old_desc": "Автоматически удаляет предыдущие zip-архивы обновляемых модов.",
            "auto_enable_title": "Автоматически включать новые моды",
            "auto_enable_desc": "Сразу активирует скачанные моды в mod-list.json.",
            "language_title": "Язык интерфейса",
            "about_title": "О программе",
            "version_label": "Версия 2.1",
            "mirror_info": "Загружает и разрешает моды через mirror-factorio.eu (без необходимости аккаунта Steam).",

            // Mod Details
            "mod_details_title": "Информация о моде",
            "author_label": "Автор:",
            "category_label": "Категория:",
            "factorio_ver_label": "Версия Factorio:",
            "latest_release_label": "Последний релиз:",
            "download_url_label": "Ссылка на скачивание:",
            "dependencies_label": "Зависимости (%d)",
            "dep_required": "Обязательный",
            "dep_recommended": "Рекомендуемый (+)",
            "dep_optional": "Опциональный (?)",
            "dep_conflict": "Несовместим (!)",
            "close_button": "Закрыть",
            "open_on_portal": "Открыть на Factorio Portal",

            // Search Portal View additions
            "filter_2_1_recent": "2.1 (Свежие)",
            "filter_2_1_all": "2.1 (Все)",
            "filter_2_0": "Factorio 2.0",
            "search_results_by_date": "%d модов (по дате обновления)",
            "loading_catalog": "Загрузка каталога модов Factorio %@...",
            "details_button": "Подробнее",
            "installed_button": "Установлен",

            // Installation Plan & Resolution additions
            "installation_plan_summary": "%d для скачивания, %d актуально",
            "download_completed_installed": "Установлено",
            "enable_all_mods": "Включить все (%d) модов",
            "current_version_label": "(текущая: v%@)",
            "status_update": "Обновление",
            "status_new": "Новый",

            // Profiles additions
            "filter_profiles_placeholder": "Фильтр профилей...",
            "saved_profiles_count": "Сохраненные профили (%d)",
            "save_profile_caption": "Сохраняет все активные моды (%d) в новый профиль.",
            "no_profiles_match": "Нет профилей, совпадающих с '%@'",
            "clear_filter": "Сбросить фильтр",
            "delete_profile_title": "Удалить профиль?",

            // Updates additions
            "updates_subtitle_checked": "Все установленные моды проверены на актуальность.",
            "updates_subtitle_count": "Доступно обновлений для %d модов.",
            "filter_updates_placeholder": "Фильтр обновлений...",
            "target_factorio_branch": "Целевая ветка Factorio: %@",
            "updating_count_inplace": "Обновление %d/%d...",
            "checking_updates_count": "Проверка %d/%d...",

            // Install Mods additions
            "install_desc": "Установка модов напрямую с зеркала с автоматическим рекурсивным разрешением зависимостей.",
            "mod_urls_or_names": "Ссылки или названия модов:",
            "popular_presets": "Популярные:",
            "clear_button": "Очистить",
            "dependency_options_title": "Параметры зависимостей и загрузки",

            // Sidebar additions
            "sidebar_section_management": "УПРАВЛЕНИЕ МОДАМИ",
            "sidebar_section_profiles": "ПРОФИЛИ И ЭКСПОРТ",
            "sidebar_section_discovery": "ПОИСК И КАТАЛОГ",
            "sidebar_section_preferences": "НАСТРОЙКИ",

            // Notifications & actions additions
            "mod_removed": "Мод '%@' удален.",
            "mods_removed_count": "Удалено модов: %d.",
            "mods_removed_and_dependents_disabled": "Удалено %d мод(ов) и отключено %d зависимых мод(ов).",
            "profile_updated": "Профиль '%@' обновлен текущей конфигурацией модов.",
            "profile_activated": "Профиль '%@' успешно активирован!",
            "profile_missing_mods_resolving": "%d модов из профиля отсутствуют на диске. Поиск зависимостей...",
            "profile_activate_failed": "Не удалось активировать профиль '%@'.",
            "profile_deleted": "Профиль '%@' удален.",

            // Profiles View additions
            "show_less": "Свернуть",
            "show_all_mods_count": "Показать все %d модов (еще %d)...",
            "update_profile_help": "Обновить этот профиль текущими активными модами",
            "delete_profile_confirm_message": "Вы уверены, что хотите удалить профиль '%@'?",

            // Export / Import additions
            "export_import_desc": "Делитесь наборами модов с друзьями или переносите сохраненные модпаки между устройствами.",
            "active_mods_ready_for_export": "Активные моды, готовые к экспорту: %d",
            "no_mods_in_import_file": "В выбранном файле не найдено записей модов.",

            // Author Browse additions
            "popular_authors": "Популярные авторы:",
            "author_browse_desc": "Введите имя автора или ссылку на портал для поиска и установки его модов.",
            "author_not_found": "Автор '%@' не найден или не имеет опубликованных модов.",
            "select_all": "Выделить все",
            "deselect_all": "Снять выделение",

            // Optional Mods additions
            "install_all_count": "Установить все (%d)",
            "optional_mods_empty_desc": "Нажмите кнопку ниже для поиска рекомендованных и опциональных дополнений к вашим модам.",

            // Settings additions
            "settings_desc": "Настройка папки хранения модов, целевой ветки Factorio и поведения менеджера.",
            "branch_version_picker_label": "Целевая ветка / Версия",
            "factorio_2_1_label": "2.1 (Актуальная)",
            "factorio_2_0_label": "2.0 (Space Age)",
            "custom_version_label": "Своя версия...",
            "custom_version_field_label": "Укажите версию:",
            "download_management_rules_title": "Правила загрузки и управления",

            // Native Table View & Installed Mods additions
            "col_active": "Вкл",
            "col_name": "Название мода",
            "col_author": "Автор",
            "col_date": "Дата",
            "col_game_ver": "Игра",
            "col_version": "Версия",
            "col_size": "Размер",
            "col_actions": "Действия",
            "official_content_header": "ОФИЦИАЛЬНЫЙ КОНТЕНТ FACTORIO И ДОПОЛНЕНИЯ",
            "community_mods_header": "УСТАНОВЛЕННЫЕ МОДЫ СООБЩЕСТВА (%d)",
            "built_in_label": "Встроенный",
            "context_mod_details": "Подробнее о моде...",
            "context_open_portal": "Открыть на Factorio Portal",
            "context_toggle_selected": "Переключить выбранные моды",
            "context_disable_mod": "Отключить мод",
            "context_enable_mod": "Включить мод",
            "context_reveal_finder": "Показать в Finder",
            "context_delete_multiple": "Удалить %d модов...",
            "context_delete_single": "Удалить мод...",
            "tooltip_open_portal": "Открыть на Factorio Portal (⌘L)",
            "tooltip_mod_details": "Подробнее о моде (⌘I)",
            "tooltip_reveal_finder": "Показать в Finder (⌘O)",
            "tooltip_delete_mod": "Удалить мод (⌫)",
            "recheck_updates_tooltip": "Проверить обновления заново",
            "launch_factorio_tooltip": "Запустить Factorio (⌘R)",

            // Installed Mods Menu & Sheets additions
            "profile_active_item": "%@ (Активен)",
            "save_current_as_profile_menu": "Сохранить текущие как профиль...",
            "manage_profiles_menu": "Управление профилями...",
            "portal_modpacks_count": "Модпаки с портала (%d)",
            "loading_modpacks_catalog": "Загрузка каталога модпаков...",
            "no_modpacks_found_for_version": "Не найдено модпаков для Factorio %@",
            "my_saved_modpacks": "Мои сохраненные модпаки",
            "modpack_actions": "Действия с модпаками",
            "refresh_modpacks_catalog": "Обновить каталог модпаков",
            "import_modpack_file_menu": "Импортировать файл модпака...",
            "export_current_modpack_menu": "Экспортировать текущий модпак...",
            "manage_modpacks_menu": "Управление модпаками...",
            "modpacks_button": "Модпаки",
            "modpacks_button_count": "Модпаки (%d)",
            "save_current_profile_title": "Сохранить текущий профиль",
            "dep_conflict_detected": "Обнаружен конфликт зависимостей",
            "dep_conflict_desc": "Удаление %d мод(ов) нарушит работу %d зависимых мод(ов).",
            "mods_to_be_deleted": "Моды, которые будут удалены:",
            "active_mods_fail_to_load": "Активные моды, которые от них зависят и не смогут загрузиться:",
            "requires_mod": "требуется %@",
            "dep_conflict_recommendation": "Рекомендуемое действие: удалить выбранные моды и автоматически отключить зависимые, чтобы Factorio мог запуститься без ошибок.",
            "delete_anyway": "Удалить в любом случае",
            "delete_and_disable_dependents": "Удалить и отключить зависимые моды",

            // Mod Details additions
            "unknown_author": "Неизвестно",
            "factorio_version_prefix": "Версия игры: %@",
            "released_date_prefix": "Дата выпуска: %@",
            "local_file_section": "Локальный файл",
            "description_tab": "Описание",
            "changelog_tab": "Ченджлог",
            "releases_tab": "Релизы и зависимости",
            "screenshots_title": "Скриншоты",
            "no_changelog": "Автор не предоставил историю изменений.",
            "no_full_description": "Подробное описание отсутствует.",
        ]
    ]
}

// Global localization helper
public func loc(_ key: String, _ args: CVarArg...) -> String {
    LocalizationManager.shared.localized(key, args)
}
