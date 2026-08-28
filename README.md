# Factorio Mod Manager (FMM)

Fast, lightweight CLI and interactive mod manager for Factorio (2.1, 2.0, 1.1) with dependency resolution and mirror downloads.

Быстрый и легковесный консольный менеджер модов для Factorio (2.1, 2.0, 1.1) с разрешением зависимостей и загрузкой с зеркала.

## Usage / Использование

Run `fmm` in your terminal  
Запустите `fmm` в терминале

## Installation / Установка

macOS / Linux / Steam Deck

- One-line installation **(Recommended)** / Установка в одну команду **(Рекомендуется):**

  ```bash
  curl -fsSL https://raw.githubusercontent.com/Christian-SC26/factorio-mod-manager/main/install.sh | bash
  ```
  > Installs to `~/.local/share/factorio-mod-manager` and links `fmm` to `~/.local/bin/fmm`.  
  > Устанавливает в `~/.local/share/factorio-mod-manager` и создает ссылку `~/.local/bin/fmm`.

- Homebrew (macOS / Linux):

  ```bash
  brew install https://raw.githubusercontent.com/Christian-SC26/factorio-mod-manager/main/Formula/fmm.rb
  ```

Windows (PowerShell / CMD)

- PowerShell one-line installer **(Recommended)** / Установка через PowerShell **(Рекомендуется):**

  ```powershell
  irm https://raw.githubusercontent.com/Christian-SC26/factorio-mod-manager/main/install.ps1 | iex
  ```
  > Installs to `%LOCALAPPDATA%\factorio-mod-manager` and adds `fmm` to your user PATH.  
  > *Устанавливает в `%LOCALAPPDATA%\factorio-mod-manager` и автоматически добавляет `fmm` в PATH.*

- Manual Windows installation / Ручная установка на Windows:

  1 - Download repository ZIP or clone / Скачайте репозиторий или клонируйте:
   ```cmd
   git clone https://github.com/Christian-SC26/factorio-mod-manager.git %LOCALAPPDATA%\factorio-mod-manager
   ```
  2 - Run `fmm.cmd` directly or add folder to your PATH. / Запускайте `fmm.cmd` напрямую или добавьте путь к папке в переменную PATH.

Python pipx / pip (Cross-platform / Кроссплатформенно)

  ```bash
  # Using pipx (isolated environment / изолированное окружение)
  pipx install git+https://github.com/Christian-SC26/factorio-mod-manager.git

  # Using standard pip / Через обычный pip
  pip install git+https://github.com/Christian-SC26/factorio-mod-manager.git
  ```

## Features / Возможности

- **Direct Mirror Downloads**: Downloads mods directly from cloud storage mirror without factorio.com account.  
  Прямая загрузка модов с зеркала без необходимости аккаунта factorio.com.
- **Instant Profile Switching**: Switch between whole modpacks (`space-age`, `pyanodons`, `krastorio2`, etc.) in 0.01s without re-downloading files.  
  Мгновенное переключение между сборками (`space-age`, `pyanodons`, `krastorio2`) за 0.01 сек без повторной загрузки архивов.
- **Deep Dependency Resolution**: Recursively resolves required, recommended (+), load order (~), and optional (?) dependencies, with conflict detection (!).  
  Рекурсивный поиск зависимостей всех типов (обязательные, рекомендованные +, опциональные ?) и выявление несовместимостей (!).
- **Factorio 2.1 / 2.0 / 1.1 Support**: Defaults to latest 2.1 mod releases or detects local game installation.  
  Поддержка актуальной Factorio 2.1 по умолчанию, а также веток 2.0 и 1.1.
- **Full mod-list.json Management**: Auto-enables installed mods, cleans old versions, and checks for updates.  
  Автоматическая активация в mod-list.json, удаление устаревших версий и проверка обновлений.
- **Export & Import**: Export modpacks to shareable JSON/text files to install anywhere.  
  Экспорт наборов модов в переносимый файл и установка на другом компьютере.
- **Interactive TUI**: Convenient terminal menu with multi-selection and language toggle (English / Russian).  
  Удобное интерактивное меню с возможностью множественного выбора и сменой языка (EN / RU).
- **Zero External Dependencies**: Pure Python 3.8+ using only standard library.  
  Работает на чистом Python 3.8+ без сторонних pip-библиотек.

## Quick Start / Быстрый старт

Run the interactive menu or use CLI commands:  
Запустите интерактивное меню или используйте консольные команды:

```bash
# Launch interactive menu (press 'q' to exit, 'L' to toggle language)
# Запуск интерактивного меню (выход по 'q', сменить язык по 'L')
fmm

# Download a mod or modpack by portal URL with all dependencies
# Скачать мод или модпак по ссылке со всеми зависимостями
fmm install https://mods.factorio.com/mod/space-exploration

# Download by mod name / Скачать по названию мода
fmm install Krastorio2

# Download multiple mods at once / Скачать сразу несколько модов через пробел
fmm install Krastorio2 flib alien-biomes

# List installed mods / Показать установленные моды
fmm list

# Check for updates / Проверить обновления
fmm check

# Update all installed mods / Обновить все установленные моды
fmm update

# Browse & download optional mods for installed mods
# Просмотреть и скачать опциональные моды для установленных модов
fmm optional

# Browse and install mods by author / creator
# Поиск и интерактивная загрузка модов по автору
fmm author Earendel

# Switch language to English or Russian / Сменить язык интерфейса
fmm lang en
fmm lang ru
```

## Profiles & Quick Switching / Профили и быстрое переключение

Profiles allow you to maintain multiple separate game setups simultaneously on the same machine:  
*Профили позволяют хранить несколько независимых сборок модов на одном компьютере и мгновенно переключаться между ними:*

```bash
# View saved profiles / Список сохраненных профилей
fmm profiles

# Switch to Pyanodons / Переключиться на Pyanodons
fmm switch pyanodons

# Switch to Space Age / Переключиться на Space Age
fmm switch space-age

# Save current enabled mod set as a new profile
# Сохранить текущий набор модов как новый профиль
fmm profile save my-pack
```

## Export & Import Modpacks / Экспорт и импорт модпаков

Export your active mod list to a file to share with friends, and import on any computer:  
*Экспортируйте активные моды в файл, чтобы поделиться с друзьями, и импортируйте на любом ПК:*

```bash
# Export active mods to a file / Экспортировать активные моды в файл
fmm export my_modpack.json

# Import and download all missing mods with dependencies
# Импортировать и автоматически скачать все недостающие моды
fmm import my_modpack.json
```

## CLI Reference / Параметры командной строки

```
usage: fmm [-h] [-d MODS_DIR] [-v FACTORIO_VERSION] [-l {en,ru}]
           {install,author,switch,profiles,profile,list,check,update,info,optional,enable,disable,remove,export,import,lang,interactive} ...

Options / Опции:
  -d, --dir PATH                Path to Factorio mods directory (auto-detected by default)
                                Путь к папке модов Factorio (по умолчанию автоопределение)
  -v, --factorio-version VER    Target Factorio branch (e.g. 2.1, 2.0, 1.1)
                                Целевая ветка игры (например 2.1, 2.0, 1.1)
  -l, --lang {en,ru}            Interface language: en (English) or ru (Russian)
                                Язык интерфейса: en (Английский) или ru (Русский)

Install Flags / Флаги команды install:
  --no-recommended             Do not download recommended '+' dependencies
                                Не скачивать рекомендуемые '+' зависимости
  --optional                   Download optional '?' dependencies
                                Скачивать опциональные '?' зависимости
  -f, --force                  Force reinstall even if version matches
                                Принудительно переустановить, даже если версия совпадает
  -y, --yes                    Automatically confirm download prompts
                                Автоматически подтверждать загрузку без запроса
  --no-clean                   Do not remove older versions of updated mods
                                Не удалять старые версии обновляемых модов
```
