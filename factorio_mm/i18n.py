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
        "menu_lang": "Switch language / Сменить язык",
        "menu_exit": "Exit",
        "prompt_choice": "Your choice [1-11, L, q]: ",
        "goodbye": "Goodbye!",
        "invalid_choice": "Invalid choice.",
        "prompt_mod_input": "Enter mod portal URL or mod name [q to cancel]: ",
        "prompt_include_optional": "Download optional ('?') dependencies? [y/N]: ",
        "prompt_confirm_download": "Start downloading {count} mod(s)? [Y/n]: ",
        "prompt_profile_name": "Enter profile name or number (1-{max}) [q to cancel]: ",
        "prompt_new_profile_name": "Enter new profile name (e.g. space-age or pyanodons) [q to cancel]: ",
        "prompt_mod_info_target": "Select mod number, enter mod name or URL [q to cancel]: ",
        "prompt_toggle_select": "Select mod numbers (e.g. 1, 3, 5-8 or 'all') [q to cancel]: ",
        "prompt_toggle_action": "Action: [T]oggle status, [E]nable all, [D]isable all [T/e/d/q]: ",
        "prompt_remove_select": "Select mod numbers/names to remove (e.g. 1, 3-5) [q to cancel]: ",
        "prompt_confirm_remove": "Are you sure you want to remove {count} selected mod(s)? [y/N]: ",
        "prompt_export_file": "Output filename [default: modpack.json, q to cancel]: ",
        "prompt_import_file": "Input filename to import [q to cancel]: ",
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
        "status_enabled": "Enabled",
        "status_disabled": "Disabled",
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
        "menu_lang": "Switch language / Сменить язык",
        "menu_exit": "Выход",
        "prompt_choice": "Ваш выбор [1-11, L, q]: ",
        "goodbye": "До свидания!",
        "invalid_choice": "Неверный выбор.",
        "prompt_mod_input": "Введите ссылку с модпортала или имя мода [q для отмены]: ",
        "prompt_include_optional": "Скачивать опциональные ('?') зависимости? [y/N]: ",
        "prompt_confirm_download": "Начать загрузку {count} мод(ов)? [Y/n]: ",
        "prompt_profile_name": "Введите имя профиля или его номер (1-{max}) [q для отмены]: ",
        "prompt_new_profile_name": "Введите имя нового профиля (например space-age или pyanodons) [q для отмены]: ",
        "prompt_mod_info_target": "Выберите номер мода, введите имя или ссылку [q для отмены]: ",
        "prompt_toggle_select": "Выберите номера модов (например 1, 3, 5-8 или 'all') [q для отмены]: ",
        "prompt_toggle_action": "Действие: [T] Переключить, [E] Включить выбранные, [D] Отключить [T/e/d/q]: ",
        "prompt_remove_select": "Выберите номера/имена модов для удаления (например 1, 3-5) [q для отмены]: ",
        "prompt_confirm_remove": "Вы уверены, что хотите удалить {count} выбранных мод(ов)? [y/N]: ",
        "prompt_export_file": "Имя файла для экспорта [по умолчанию: modpack.json, q для отмены]: ",
        "prompt_import_file": "Имя файла для импорта [q для отмены]: ",
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
        "status_enabled": "Включен",
        "status_disabled": "Отключен",
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
        "profile_inactive": "не активен",
        "profile_col_num": "#",
        "profile_col_status": "Статус",
        "profile_col_name": "Имя профиля",
        "profile_col_mods": "Активных модов",
        "profile_switch_hint": "Для переключения: fmm switch <имя>",
        "profile_activated": "Профиль '{name}' успешно активирован!",
        "profile_ready": "Все моды профиля '{name}' включены в mod-list.json. Игра готова к запуску!",
        "profile_missing_mods": "Внимание: следующие моды из профиля отсутствуют на диске:",
        "profile_download_missing": "Скачать недостающие моды с зеркала? [Y/n]: ",
        "profile_not_found": "Профиль '{name}' не найден",
        "profile_deleted": "Профиль '{name}' удален.",
        "lang_changed": "Язык переключен на Русский.",
    }
}


class I18n:
    def __init__(self, lang: Optional[str] = None):
        self.lang = lang or self.load_saved_lang() or "en"

    def load_saved_lang(self) -> Optional[str]:
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    return data.get("language")
            except Exception:
                pass
        return None

    def save_lang(self, lang: str):
        self.lang = lang
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        data = {}
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception:
                data = {}
        data["language"] = lang
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)

    def set_lang(self, lang: str):
        if lang in STRINGS:
            self.save_lang(lang)

    def toggle_lang(self) -> str:
        new_lang = "ru" if self.lang == "en" else "en"
        self.save_lang(new_lang)
        return new_lang

    def t(self, key: str, **kwargs) -> str:
        lang_dict = STRINGS.get(self.lang, STRINGS["en"])
        val = lang_dict.get(key, STRINGS["en"].get(key, key))
        if kwargs:
            try:
                return val.format(**kwargs)
            except Exception:
                return val
        return val


# Global i18n instance
i18n = I18n()
