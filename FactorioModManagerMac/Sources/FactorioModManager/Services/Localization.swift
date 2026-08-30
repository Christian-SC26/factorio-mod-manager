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
            "activate_profile": "Activate Profile",
            "active_badge": "ACTIVE",
            "delete_profile": "Delete",
            "profile_mods_count": "%d active mods",
            "missing_mods_warning": "Warning: %d mods in this profile are missing on disk.",
            "download_missing_button": "Download Missing Mods",
            "no_profiles_saved": "No profiles saved yet.",

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
            "version_label": "Version 2.1 Native Swift",
            "mirror_info": "Downloads are fetched from the fast re146.dev cloud mirror.",

            // Mod Details
            "mod_details_title": "Mod Details",
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
            "activate_profile": "Активировать профиль",
            "active_badge": "АКТИВЕН",
            "delete_profile": "Удалить",
            "profile_mods_count": "%d активных модов",
            "missing_mods_warning": "Внимание: %d модов из этого профиля отсутствуют на диске.",
            "download_missing_button": "Скачать недостающие моды",
            "no_profiles_saved": "Сохраненных профилей пока нет.",

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
            "about_title": "О программе Factorio Mod Manager",
            "version_label": "Версия 2.1 Нативный Swift",
            "mirror_info": "Загрузка модов осуществляется с быстрого облачного зеркала re146.dev.",

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
        ]
    ]
}

// Global localization helper
public func loc(_ key: String, _ args: CVarArg...) -> String {
    LocalizationManager.shared.localized(key, args)
}
