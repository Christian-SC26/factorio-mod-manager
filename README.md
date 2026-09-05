# Factorio Mod Manager (FMM) for macOS

[![Release](https://img.shields.io/github/v/release/Christian-SC26/factorio-mod-manager?color=orange&label=Release)](https://github.com/Christian-SC26/factorio-mod-manager/releases)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Быстрое и легковесное нативное приложение для macOS (Swift / SwiftUI) для управления модами **Factorio 2.1, 2.0 и 1.1** с автоматическим разрешением зависимостей, мгновенным переключением профилей и прямой загрузкой с облачного зеркала.

Fast, lightweight native macOS app (Swift / SwiftUI) for managing **Factorio (2.1, 2.0, 1.1)** mods with automatic dependency resolution, instant profile switching, and mirror downloads.

---

## Возможности / Features

- 🚀 **Прямая загрузка с зеркала**: Скачивание модов напрямую из облачного зеркала [re146.dev](https://re146.dev) без ввода логина и пароля от factorio.com.
- ⚡ **Рекурсивное разрешение зависимостей**: Автоматический расчет графа обязательных, рекомендуемых (`+`) и опциональных (`?`) модов с детекцией конфликтов (`!`) и интерактивным деревом зависимостей.
- ⏱ **Мгновенные профили (0.01s)**: Мгновенное переключение между целыми сборками (*Space Age*, *Krastorio 2*, *Pyanodons*, *SE*) без повторной загрузки файлов.
- 🔍 **Поиск по порталу и авторам**: Поиск модов под Factorio 2.1 / 2.0 / 1.1, просмотр сборок конкретных авторов и массовая установка.
- 📖 **Карточка мода с Markdown и галереей**: Отображение форматированного описания мода, истории версий (changelog) без лагов и полноэкранный просмотр скриншотов.
- 🧩 **Умный подбор дополнений**: Сканирование активных модов и предложение совместимых опциональных аддонов.
- 🔄 **Обновление в один клик**: Проверка обновлений всех установленных модов с показом изменений версий.
- 📦 **Экспорт и импорт**: Сохранение сборок в файл JSON или список ссылок для легкой передачи друзьям.
- ⌨️ **Управление с клавиатуры**: Полная навигация стрелками и Vim-клавишами (`J`/`K`), выделение модов (`Space`), запуск Factorio (`Cmd+R`). Работает корректно на любой раскладке клавиатуры.
- 🌐 **Двуязычный интерфейс**: Полная локализация на русский и английский языки с мгновенным переключением в тулбаре.

---

## Установка / Installation

### Готовая сборка (Рекомендуется)
1. Скачайте архив **`FMM-macOS.zip`** со страницы [**Releases**](https://github.com/Christian-SC26/factorio-mod-manager/releases).
2. Распакуйте и переместите **`FMM.app`** в папку **«Программы»** (`/Applications`).

> **Примечание при первом запуске**:  
> Если macOS покажет предупреждение о неподписанном приложении: нажмите по `FMM.app` правой кнопкой мыши (или `Control + клик`) и выберите **«Открыть»**.

---

### Сборка из исходников

Требуются macOS 13.0+ и установленные инструменты командной строки Xcode (`xcode-select --install`):

```bash
git clone https://github.com/Christian-SC26/factorio-mod-manager.git
cd factorio-mod-manager/FactorioModManagerMac
./build_app.sh
```

Собранное приложение появится в папке: `FactorioModManagerMac/FMM.app`.

---

## Горячие клавиши / Keyboard Shortcuts

| Клавиша | Действие |
|---|---|
| `Cmd + R` | Запустить Factorio |
| `↑` / `↓` или `K` / `J` | Навигация по списку модов |
| `Space` | Выделить / снять выделение мода |
| `Enter` | Открыть подробную информацию о моде |
| `Esc` | Закрыть модальное окно / карточку |
| `D` / `C` / `R` | Вкладки Description / Changelog / Releases в карточке мода |

---

## Системные требования

- **ОС**: macOS 13.0 (Ventura) или новее (Apple Silicon & Intel).
- **Игра**: Factorio 2.1, 2.0 или 1.1 (автоопределение установленной версии).

---

## Лицензия / License

Распространяется под лицензией [MIT](LICENSE).
