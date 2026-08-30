# Factorio Mod Manager for macOS (Native Swift & SwiftUI)

Нативное macOS-приложение для управления модами Factorio (2.1, 2.0, 1.1) с рекурсивным разрешением зависимостей, поддержкой профилей, поиском на портале и прямой загрузкой с облачного зеркала [re146.dev](https://re146.dev).

---

## Возможности / Features

- ⚡ **100% Native macOS & SwiftUI**: Создано с использованием SwiftUI, Swift Concurrency (`async/await`, Actors), адаптировано под Apple Human Interface Guidelines.
- 🚀 **Прямая загрузка с зеркала**: Быстрая загрузка архивов модов без авторизации на `factorio.com`.
- 🔄 **Рекурсивное разрешение зависимостей**:
  - Обязательные зависимости
  - Рекомендованные (`+`)
  - Опциональные (`?`)
  - Детекция конфликтов и несовместимостей (`!`)
  - Интерактивное визуальное дерево зависимостей
- ⏱ **Мгновенное переключение профилей**: Переключение между целыми сборками (`Space Age`, `Krastorio 2`, `Pyanodons` и т.д.) за 0.01 секунды.
- 🔍 **Поиск по порталу и авторам**: Полнотекстовый поиск по порталу модов, фильтр для Factorio 2.x, просмотр и массовая загрузка модов выбранного автора.
- 🧩 **Поиск опциональных модов**: Автоматическое сканирование установленных модов и предложение рекомендуемых аддонов.
- 📦 **Экспорт и импорт сборок**: Экспорт активного набора в JSON или текстовый файл ссылок, импорт на любом другом компьютере.
- 🔄 **Проверка и обновление**: Проверка обновлений всех установленных модов в 1 клик с показом различий версий.
- 🌐 **Двуязычный интерфейс**: Полная поддержка русского и английского языков с мгновенным переключением.

---

## Запуск и сборка / Build & Run

### 1. Запуск из терминала (Swift CLI / SwiftUI App)

```bash
cd FactorioModManagerMac
swift run
```

### 2. Открытие в Xcode

```bash
cd FactorioModManagerMac
open Package.swift
```
*Либо откройте `Package.swift` прямо через меню `Xcode -> File -> Open...`.*

### 3. Релизная сборка

```bash
cd FactorioModManagerMac
swift build -c release
```
Исполняемый файл будет находиться в:
`.build/release/FactorioModManagerMac`

### 4. Запуск тестов

```bash
cd FactorioModManagerMac
swift test
```

---

## Структура проекта

```
FactorioModManagerMac/
├── Package.swift
├── Sources/
│   └── FactorioModManager/
│       ├── App/
│       │   ├── FactorioModManagerApp.swift   # Главная точка входа (@main)
│       │   └── AppState.swift               # Центральный координатор состояния UI и сервисов
│       ├── Models/
│       │   ├── FactorioVersion.swift        # Модель семантической версии Factorio
│       │   ├── Dependency.swift             # Модель и парсер зависимостей (!, +, ?, op ver)
│       │   ├── ModInfo.swift                # Модели метаданных модов и релизов
│       │   ├── LocalMod.swift               # Модель локального мода (zip / папка)
│       │   └── Profile.swift                # Модель профиля сборок
│       ├── Services/
│       │   ├── ModPortalClient.swift        # Асинхронный клиент API re146 и mods.factorio.com
│       │   ├── ModListManager.swift         # Управление папкой mods и mod-list.json
│       │   ├── DependencyResolver.swift     # Движок разрешения графа зависимостей и конфликтов
│       │   ├── ModDownloader.swift          # Загрузчик с прогрессом, контролем целостности и скоростью
│       │   └── Localization.swift           # Локализация (RU / EN)
│       └── Views/
│           ├── ContentView.swift            # Корневой NavigationSplitView с тулбаром
│           ├── SidebarView.swift            # Боковое меню разделов
│           ├── InstalledModsView.swift      # Управление установленными модами (поиск, фильтры, удаление)
│           ├── InstallModsView.swift        # Ввод ссылок/имен и запуск разрешения
│           ├── ResolutionSheetView.swift    # Окно плана установки, дерева зависимостей и загрузки
│           ├── UpdatesView.swift            # Центр проверки и установки обновлений
│           ├── ProfilesView.swift           # Сохранение и быстрое переключение профилей
│           ├── SearchPortalView.swift       # Онлайн-поиск модов на портале
│           ├── AuthorBrowseView.swift       # Просмотр и загрузка модов по автору
│           ├── OptionalModsView.swift       # Поиск и установка опциональных зависимостей
│           ├── ExportImportView.swift       # Экспорт и импорт сборок (.json / .txt)
│           ├── ModDetailSheet.swift         # Подробная карточка мода
│           ├── SettingsView.swift           # Настройки папки, версии Factorio, языка
│           └── Components/
│               ├── BadgeView.swift          # Чипы статусов и версий
│               ├── ProgressBarView.swift    # Индикатор прогресса загрузки
│               └── DependencyTreeView.swift # Иерархическое дерево зависимостей
└── Tests/
    └── FactorioModManagerTests/
        ├── FactorioVersionTests.swift
        └── DependencyTests.swift
```
