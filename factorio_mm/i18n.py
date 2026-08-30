"""Localization support (English and Russian) for Factorio Mod Manager."""

from __future__ import annotations
import json
import os
from pathlib import Path
from typing import Dict, Optional

CONFIG_DIR = Path.home() / ".config" / "fmm"
CONFIG_FILE = CONFIG_DIR / "config.json"

STRINGS: Dict[str, Dict[str, str]] = {
    "en": {
        "banner_title": "FACTORIO MOD MANAGER",
        "banner_subtitle": "Fast mod and modpack manager with dependency resolution",
        "mods_dir": "Mods directory:",
        "factorio_ver": "Factorio version:",
        "ver_auto": "Auto / 2.1 (current)",
        "menu_title": "Select an action:",
        "menu_install": "Download mod or modpack (by URL or name)",
        "menu_switch": "Switch modpack profile",
        "menu_save_profile": "Save current modpack as profile",
        "menu_check": "Check for mod updates",
        "menu_update": "Update all installed mods",
        "menu_list": "List installed mods",
        "menu_info": "View mod information",
        "menu_toggle": "Enable / Disable mods (interactive selection)",
        "menu_remove": "Remove mods (interactive selection)",
        "menu_export": "Export modpack to file",
        "menu_import": "Import modpack from file",
        "menu_optional": "Browse & download optional mods for installed mods",
        "menu_author": "Browse & download mods by author / creator",
        "menu_search": "Search & download mods by keyword / description",
        "menu_lang": "Switch language / Сменить язык",
        "menu_exit": "Exit",
        "prompt_choice": "Your choice [1-14, L, Q]: ",
        "goodbye": "Goodbye!",
        "invalid_choice": "Invalid choice.",
        "prompt_mod_input": "Enter mod portal URL(s) or name(s) separated by space [q to cancel]: ",
        "prompt_include_optional": "Download optional ('?') dependencies? [y/N]: ",
        "prompt_confirm_download": "Start downloading {count} mod(s)? [Y/n]: ",
        "prompt_profile_name": "Enter profile name or number (1-{max}) [q to cancel]: ",
        "prompt_new_profile_name": "Enter new profile name (e.g. space-age or pyanodons) [q to cancel]: ",
        "prompt_mod_info_target": "Select mod number, enter mod name or URL [q to cancel]: ",
        "prompt_toggle_select": "Select mod numbers (e.g. 1 3 5-8 or 'all') [q to cancel]: ",
        "prompt_toggle_action": "Action: [T]oggle status, [E]nable all, [D]isable all [T/e/d/q]: ",
        "prompt_remove_select": "Select mod numbers/names to remove (e.g. 1 3-5, 'disabled' or 'all') [q to cancel]: ",
        "no_disabled_mods": "[!] No disabled mods found to remove.",
        "prompt_confirm_remove": "Are you sure you want to remove {count} selected mod(s)? [y/N]: ",
        "prompt_export_file": "Output filename [default: modpack.json, q to cancel]: ",
        "prompt_import_file": "Input filename to import [q to cancel]: ",
        "prompt_optional_select": "Select optional mod numbers to download (e.g. 1 3 or 'all') [q to cancel]: ",
        "prompt_author_input": "Enter author username or profile URL [q to cancel]: ",
        "prompt_author_select": "Select mod numbers to download (e.g. 1 3 5-8 or 'all') [q to cancel]: ",
        "fetching_author_mods": "Fetching mod list for author '{author}'...",
        "author_mods_header": "Mods by author '{author}' ({count} total: {active} active, {deprecated} deprecated):",
        "author_not_found": "[!] Author '{author}' not found or has no published mods.",
        "prompt_search_query": "Enter search keyword(s) (e.g. 'mulana', 'train', 'solar') [q to cancel]: ",
        "prompt_search_scope": "Search scope:\n  1) Search Portal (Online: all versions)\n  2) Search Portal (Online: Factorio 2.x only) [Default]\n  3) Search Installed Mods (Offline: title, name, description)\nSelect mode [1-3, default 2, q to cancel]: ",
        "searching_portal": "Searching Factorio Mod Portal for '{query}'...",
        "searching_local": "Searching local installed mods for '{query}'...",
        "search_results_header": "Search results for '{query}' ({count} found):",
        "search_no_results": "[!] No mods found matching '{query}'.",
        "prompt_search_select": "Select mod numbers to download (e.g. 1 3 5-8 or 'all') [q to cancel]: ",
        "scanning_optional": "Scanning installed mods for optional dependencies...",
        "no_optional_found": "[OK] No missing optional mods found. All optional dependencies are already installed or none were specified.",
        "optional_header": "Available optional mods for installed mods:",
        "suggested_by_col": "Suggested by",
        "press_enter": "Press Enter to continue...",
        "resolving_deps": "Resolving dependencies for: {targets}...",
        "dep_tree": "Dependency tree:",
        "conflicts_found": "CONFLICTS DETECTED:",
        "missing_mods": "Missing mods:",
        "warnings": "Warnings:",
        "install_plan": "Installation plan:",
        "mods_to_download": "To be downloaded and installed ({count}):",
        "mods_up_to_date": "Already installed and up to date ({count}):",
        "all_up_to_date": "[OK] All mods and dependencies are already installed and up to date!",
        "cancelled": "Operation cancelled.",
        "download_started": "Downloading {count} mod(s) from mirror...",
        "installed_success": "[OK] Successfully installed {count} mod(s)!",
        "installed_partial": "Finished: {success} succeeded, {failed} failed.",
        "game_ready": "All mods are ready to play in {path}",
        "no_mods_found": "No mods found in '{path}'.",
        "installed_mods_header": "Installed mods in {path}:",
        "status_col": "Status",
        "name_col": "Mod Name",
        "version_col": "Version",
        "file_col": "File",
        "title_col": "Title",
        "author_col": "Author",
        "status_enabled": "Enabled",
        "status_disabled": "Disabled",
        "status_installed": "Installed",
        "status_new": "New",
        "total_mods_summary": "Total: {total} (Enabled: {enabled}, Disabled: {disabled})",
        "checking_updates": "Checking updates for {count} mods...",
        "update_available": "Update available: {name}: {local} -> {remote}",
        "mod_up_to_date": "{name} v{ver} is up to date",
        "all_updates_ok": "[OK] All installed mods are up to date!",
        "updates_count": "Updates available: {count}",
        "prompt_apply_updates": "Download and install all {count} updates now? [Y/n]: ",
        "run_update_hint": "Run 'fmm update' to download updates.",
        "mod_info_header": "{title} ({name})",
        "author_label": "Author:",
        "category_label": "Category:",
        "downloads_label": "Downloads:",
        "description_label": "Description:",
        "latest_release_label": "Latest release:",
        "download_url_label": "Download URL:",
        "deps_label": "Dependencies ({count}):",
        "dep_req": "[Required]",
        "dep_order": "[Order]",
        "dep_rec": "[Recommended (+)]",
        "dep_opt": "[Optional (?)]",
        "dep_conflict": "[Incompatible (!)]",
        "mod_state_changed": "Mod '{name}' is now {state}.",
        "mods_toggled_count": "[OK] Updated state for {count} mod(s).",
        "mod_removed": "Mod '{name}' removed ({count} files).",
        "mods_removed_count": "[OK] Removed {count} mod(s).",
        "export_success": "[OK] Exported {count} active mods to '{path}'",
        "import_start": "Importing {count} mods from '{path}'...",
        "file_not_found": "File '{path}' not found.",
        "profile_saved": "[OK] Current setup saved as profile '{name}'",
        "no_profiles": "No saved profiles yet.",
        "create_profile_hint": "Create one using: fmm profile save <name>",
        "profiles_header": "Saved mod profiles:",
        "profile_active": "ACTIVE",
        "profile_inactive": "inactive",
        "profile_col_num": "#",
        "profile_col_status": "Status",
        "profile_col_name": "Profile Name",
        "profile_col_mods": "Active Mods",
        "profile_switch_hint": "To switch: fmm switch <name>",
        "profile_activated": "Profile '{name}' activated successfully!",
        "profile_ready": "All profile mods enabled in mod-list.json. Ready to play!",
        "profile_missing_mods": "Warning: the following mods from the profile are missing on disk:",
        "profile_download_missing": "Download missing mods from mirror? [Y/n]: ",
        "profile_not_found": "Profile '{name}' not found",
        "profile_deleted": "Profile '{name}' deleted.",
        "lang_changed": "Language switched to English.",
        # Resolver & API warnings
        "warn_version_conflict": "Version conflict for '{name}': requires {op} {req_ver} (for {parent}), but release {selected_ver} is selected",
        "warn_mod_not_found": "Could not find mod '{name}' (requested by '{parent}'): {err}",
        "warn_no_matching_release": "No matching version found for '{name}' ({op} {req_ver}, Factorio: {f_ver})",
        "warn_base_mismatch": "Mod '{name} v{ver}' requires Factorio {op} {req_ver}, but target game version is {target_ver}",
        "warn_conflict": "Mod '{mod_a}' is incompatible with '{mod_b}'",
        "warn_conflict_installed": "Mod '{mod_a}' is incompatible with installed mod '{mod_b}'",
        "root_user": "user",
        "any_version": "any",
        "api_mod_not_found": "Mod '{name}' not found on mod portal (404 Not Found)",
        "api_req_error": "API request error: {err}",
        "api_fetch_failed": "Failed to fetch mod info for '{name}': {err}",
        "api_data_corrupted": "Mod '{name}' not found or data corrupted",
    },
    "ru": {
        "banner_title": "FACTORIO MOD MANAGER",
        "banner_subtitle": "Быстрый менеджер модов и модпаков с разрешением зависимостей",
        "mods_dir": "Папка модов:",
        "factorio_ver": "Версия Factorio:",
        "ver_auto": "Авто / 2.1 (актуальная)",
        "menu_title": "Выберите действие:",
        "menu_install": "Скачать мод или модпак (по ссылке или названию)",
        "menu_switch": "Переключить профиль / сборку (Быстрое переключение)",
        "menu_save_profile": "Сохранить текущий набор модов как профиль",
        "menu_check": "Проверить обновления установленных модов",
        "menu_update": "Обновить все установленные моды",
        "menu_list": "Список установленных модов",
        "menu_info": "Информация о моде",
        "menu_toggle": "Включить / Отключить моды (интерактивный выбор)",
        "menu_remove": "Удалить моды (интерактивный выбор)",
        "menu_export": "Экспорт модпака в файл",
        "menu_import": "Импорт модпака из файла",
        "menu_optional": "Опциональные моды для установленных (выбор и загрузка)",
        "menu_author": "Поиск и загрузка модов по автору",
        "menu_search": "Поиск и загрузка модов по ключевым словам / описанию",
        "menu_lang": "Switch language / Сменить язык",
        "menu_exit": "Выход",
        "prompt_choice": "Ваш выбор [1-14, L, Q]: ",
        "goodbye": "До свидания!",
        "invalid_choice": "Неверный выбор.",
        "prompt_mod_input": "Введите ссылки или имена модов через пробел [q для отмены]: ",
        "prompt_include_optional": "Скачивать опциональные ('?') зависимости? [y/N]: ",
        "prompt_confirm_download": "Начать загрузку {count} мод(ов)? [Y/n]: ",
        "prompt_profile_name": "Введите имя профиля или его номер (1-{max}) [q для отмены]: ",
        "prompt_new_profile_name": "Введите имя нового профиля (например space-age или pyanodons) [q для отмены]: ",
        "prompt_mod_info_target": "Выберите номер мода, введите имя или ссылку [q для отмены]: ",
        "prompt_toggle_select": "Выберите номера модов (например 1 3 5-8 или 'all') [q для отмены]: ",
        "prompt_toggle_action": "Действие: [T] Переключить, [E] Включить выбранные, [D] Отключить [T/e/d/q]: ",
        "prompt_remove_select": "Выберите номера/имена модов для удаления (например 1 3-5, 'disabled'/'откл' или 'all') [q для отмены]: ",
        "no_disabled_mods": "[!] Отключенных модов для удаления не найдено.",
        "prompt_confirm_remove": "Вы уверены, что хотите удалить {count} выбранных мод(ов)? [y/N]: ",
        "prompt_export_file": "Имя файла для экспорта [по умолчанию: modpack.json, q для отмены]: ",
        "prompt_import_file": "Имя файла для импорта [q для отмены]: ",
        "prompt_optional_select": "Выберите номера опциональных модов для загрузки (например 1 3 или 'all') [q для отмены]: ",
        "prompt_author_input": "Введите имя автора или ссылку на профиль [q для отмены]: ",
        "prompt_author_select": "Выберите номера модов для загрузки (например 1 3 5-8 или 'all') [q для отмены]: ",
        "fetching_author_mods": "Загрузка списка модов автора '{author}'...",
        "author_mods_header": "Моды автора '{author}' (всего: {count}, активных: {active}, устаревших: {deprecated}):",
        "author_not_found": "[!] Автор '{author}' не найден или у него нет опубликованных модов.",
        "prompt_search_query": "Введите поисковый запрос (например 'mulana', 'train', 'solar') [q для отмены]: ",
        "prompt_search_scope": "Режим поиска:\n  1) Поиск на портале (Онлайн: все версии)\n  2) Поиск на портале (Онлайн: только Factorio 2.x) [По умолчанию]\n  3) Поиск среди установленных модов (Офлайн: имя, название, описание)\nВыберите режим [1-3, по умолчанию 2, q для отмены]: ",
        "searching_portal": "Поиск на портале Factorio по запросу '{query}'...",
        "searching_local": "Поиск среди установленных модов по запросу '{query}'...",
        "search_results_header": "Результаты поиска по запросу '{query}' (найдено: {count}):",
        "search_no_results": "[!] Моды по запросу '{query}' не найдены.",
        "prompt_search_select": "Выберите номера модов для загрузки (например 1 3 5-8 или 'all') [q для отмены]: ",
        "scanning_optional": "Поиск опциональных зависимостей для установленных модов...",
        "no_optional_found": "[OK] Не найдено недостающих опциональных модов. Все опциональные зависимости уже установлены или отсутствуют.",
        "optional_header": "Доступные опциональные моды для установленных модов:",
        "suggested_by_col": "Рекомендован в",
        "press_enter": "Нажмите Enter для продолжения...",
        "resolving_deps": "Разрешение зависимостей для: {targets}...",
        "dep_tree": "Дерево зависимостей:",
        "conflicts_found": "ОБНАРУЖЕНЫ КОНФЛИКТЫ:",
        "missing_mods": "Не найдены моды:",
        "warnings": "Предупреждения:",
        "install_plan": "План установки:",
        "mods_to_download": "Будут скачаны и установлены ({count}):",
        "mods_up_to_date": "Уже установлены и актуальны ({count}):",
        "all_up_to_date": "[OK] Все моды и зависимости уже установлены и актуальны!",
        "cancelled": "Действие отменено.",
        "download_started": "Загрузка {count} мод(ов) с зеркала...",
        "installed_success": "[OK] Успешно установлено {count} мод(ов)!",
        "installed_partial": "Завершено: {success} успешно, {failed} с ошибками.",
        "game_ready": "Все моды готовы к игре в {path}",
        "no_mods_found": "В папке '{path}' моды не найдены.",
        "installed_mods_header": "Установленные моды в {path}:",
        "status_col": "Статус",
        "name_col": "Имя мода",
        "version_col": "Версия",
        "file_col": "Файл",
        "title_col": "Название",
        "author_col": "Автор",
        "status_enabled": "Включен",
        "status_disabled": "Отключен",
        "status_installed": "Установлен",
        "status_new": "Новый",
        "total_mods_summary": "Всего: {total} (Включено: {enabled}, Отключено: {disabled})",
        "checking_updates": "Проверка обновлений для {count} модов...",
        "update_available": "Доступно обновление: {name}: {local} -> {remote}",
        "mod_up_to_date": "{name} v{ver} актуален",
        "all_updates_ok": "[OK] Все установленные моды имеют актуальные версии!",
        "updates_count": "Доступно обновлений: {count}",
        "prompt_apply_updates": "Скачать и установить все {count} обновлений прямо сейчас? [Y/n]: ",
        "run_update_hint": "Запустите 'fmm update' для загрузки обновлений.",
        "mod_info_header": "{title} ({name})",
        "author_label": "Автор:",
        "category_label": "Категория:",
        "downloads_label": "Загрузок:",
        "description_label": "Описание:",
        "latest_release_label": "Последний релиз:",
        "download_url_label": "Ссылка для скачивания:",
        "deps_label": "Зависимости ({count}):",
        "dep_req": "[Обязательный]",
        "dep_order": "[Порядок]",
        "dep_rec": "[Рекомендуемый (+)]",
        "dep_opt": "[Опциональный (?)]",
        "dep_conflict": "[Несовместим (!)]",
        "mod_state_changed": "Мод '{name}' {state}.",
        "mods_toggled_count": "[OK] Обновлен статус для {count} мод(ов).",
        "mod_removed": "Мод '{name}' удален ({count} файлов).",
        "mods_removed_count": "[OK] Удалено {count} мод(ов).",
        "export_success": "[OK] Список из {count} активных модов экспортирован в '{path}'",
        "import_start": "Импорт {count} модов из '{path}'...",
        "file_not_found": "Файл '{path}' не найден.",
        "profile_saved": "[OK] Текущий профиль сохранен как '{name}'",
        "no_profiles": "Сохраненных профилей пока нет.",
        "create_profile_hint": "Создайте профиль с помощью: fmm profile save <имя>",
        "profiles_header": "Сохраненные профили модов:",
        "profile_active": "АКТИВЕН",
        "profile_inactive": "неактивен",
        "profile_col_num": "#",
        "profile_col_status": "Статус",
        "profile_col_name": "Имя профиля",
        "profile_col_mods": "Активных модов",
        "profile_switch_hint": "Для переключения: fmm switch <имя>",
        "profile_activated": "Профиль '{name}' успешно активирован!",
        "profile_ready": "Все моды профиля включены в mod-list.json. Готово к игре!",
        "profile_missing_mods": "Предупреждение: следующие моды из профиля отсутствуют на диске:",
        "profile_download_missing": "Скачать недостающие моды с зеркала? [Y/n]: ",
        "profile_not_found": "Профиль '{name}' не найден",
        "profile_deleted": "Профиль '{name}' удален.",
        "lang_changed": "Язык переключен на русский.",
        # Resolver & API warnings
        "warn_version_conflict": "Конфликт версий для '{name}': требуется {op} {req_ver} (для {parent}), но выбрана версия {selected_ver}",
        "warn_mod_not_found": "Не удалось найти мод '{name}' (запрошен '{parent}'): {err}",
        "warn_no_matching_release": "Не найдена подходящая версия для '{name}' ({op} {req_ver}, Factorio: {f_ver})",
        "warn_base_mismatch": "Мод '{name} v{ver}' требует Factorio {op} {req_ver}, но целевая версия игры {target_ver}",
        "warn_conflict": "Мод '{mod_a}' несовместим с '{mod_b}'",
        "warn_conflict_installed": "Мод '{mod_a}' несовместим с установленным модом '{mod_b}'",
        "root_user": "пользователь",
        "any_version": "любая",
        "api_mod_not_found": "Мод '{name}' не найден на портале модов (404 Not Found)",
        "api_req_error": "Ошибка API запроса: {err}",
        "api_fetch_failed": "Не удалось получить данные мода '{name}': {err}",
        "api_data_corrupted": "Мод '{name}' не найден или данные повреждены",
    }
}


class I18n:
    def __init__(self):
        self.locale = self._load_locale()

    def _load_locale(self) -> str:
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    loc = data.get("language")
                    if loc in ("en", "ru"):
                        return loc
            except Exception:
                pass

        sys_lang = os.environ.get("LANG", "").lower()
        if "ru" in sys_lang or "russian" in sys_lang:
            return "ru"
        return "en"

    def save_locale(self, loc: str) -> None:
        if loc not in ("en", "ru"):
            return
        self.locale = loc
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        try:
            cfg = {}
            if CONFIG_FILE.exists():
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    cfg = json.load(f)
            cfg["language"] = loc
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(cfg, f, indent=2)
        except Exception:
            pass

    @property
    def lang(self) -> str:
        return self.locale

    @lang.setter
    def lang(self, val: str) -> None:
        self.save_locale(val)

    def set_lang(self, loc: str) -> None:
        self.save_locale(loc)

    def toggle_lang(self) -> str:
        new_loc = "en" if self.locale == "ru" else "ru"
        self.save_locale(new_loc)
        return new_loc

    def t(self, key: str, **kwargs) -> str:
        table = STRINGS.get(self.locale, STRINGS["en"])
        val = table.get(key)
        if val is None:
            val = STRINGS["en"].get(key, key)
        if kwargs:
            try:
                return val.format(**kwargs)
            except Exception:
                return val
        return val


i18n = I18n()
