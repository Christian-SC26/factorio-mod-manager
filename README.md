<p align="center"><img src="FactorioModManagerMac/Resources/AppIcon.png" width="96" alt="Factorio Mod Manager icon"></p>

# Factorio Mod Manager for macOS

**English** · [Русский](README.ru.md)

[![Release](https://img.shields.io/github/v/release/Christian-SC26/factorio-mod-manager?label=release)](https://github.com/Christian-SC26/factorio-mod-manager/releases/latest)
[![Release build](https://github.com/Christian-SC26/factorio-mod-manager/actions/workflows/release.yml/badge.svg)](https://github.com/Christian-SC26/factorio-mod-manager/actions/workflows/release.yml)
[![macOS 13+ · Apple Silicon](https://img.shields.io/badge/macOS-13%2B%20·%20Apple%20Silicon-blue)](#install)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A native macOS app that installs Factorio mods with all their dependencies, needs no factorio.com login, and switches between mod sets in one click.

![Installed mods table: built-in expansions on top, twelve community mods below, two of them disabled and two showing available updates](docs/screenshots/installed.png)

**Status:** actively developed by a single maintainer. CI runs the full test suite before it builds a release, and a single failing test stops the release.

## Why FMM

The in-game mod manager also installs dependencies, but it needs a factorio.com account and only works inside the game. FMM works outside it:

- **No login.** Downloads come from the community mirror [re146.dev](https://re146.dev).
- **Dependencies before download.** FMM resolves required, recommended (`+`) and optional (`?`) dependencies and shows conflicts (`!`) before it fetches anything.
- **Whole lists at once.** Paste portal links, mod names, `name@1.2.3` or a modpack file, and FMM installs all of it in one pass.
- **Profiles.** Save the set of enabled mods as a profile. Switching profiles rewrites `mod-list.json` and downloads nothing again.

**Pick another tool** if you run Windows or Linux, have an Intel Mac and don't want to build from source, or need downloads from the official portal only. A third party runs the mirror: when it is down, FMM cannot download mods.

## Install

1. Download `FMM-macOS.zip` from the [latest release](https://github.com/Christian-SC26/factorio-mod-manager/releases/latest). The build targets Apple Silicon and macOS 13 or later.
2. Unzip it and drag `FMM.app` into Applications.
3. The app is not notarized, so macOS blocks the first launch. Open System Settings → Privacy & Security and click **Open Anyway**. Or run this in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/FMM.app
   ```

FMM looks for mods in `~/Library/Application Support/factorio/mods`. You can pick another folder in the app's settings.

## Features

- Installed mods table: enable, disable, delete, filter by author.
- Search the mod portal and author pages, install several mods at once.
- Mod page with description, changelog and screenshots.
- Suggestions for optional add-ons to the mods you have.
- Update check across all installed mods.
- Modpack export and import as JSON or as a text file of links.
- Release selection for your game version (2.1, 2.0 or 1.1), detected from the Factorio log.
- English and Russian interface.

| Mod page | Updates |
|---|---|
| ![Mod page for Project Cybersyn with screenshots, description, changelog and releases tabs](docs/screenshots/details.png) | ![Updates tab listing Todo List and Factorio Library with old and new versions](docs/screenshots/updates.png) |
| **Profiles** | **Portal search** |
| ![Profiles tab with two saved profiles and their mods](docs/screenshots/profiles.png) | ![Portal search showing recently updated mods for Factorio 2.1 with install buttons](docs/screenshots/search.png) |

## Keyboard shortcuts

Shortcuts follow physical key positions, so they work on non-Latin layouts too.

| Keys | Action |
|---|---|
| `⌘R` | Launch Factorio (from Applications or your Steam library) |
| `⌘N` | Install mods by link or name |
| `⌘U` | Check for updates |
| `⌘F` | Search |
| `↓` `↑` or `J` `K` | Move through the list |
| `Space` | Enable or disable the selected mods |
| `⌘I` | Mod info and dependencies |
| `⌘/` | All shortcuts |

## Build from source

You need macOS 13 or later, the Xcode command line tools (`xcode-select --install`) and an internet connection to fetch the [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) package.

```bash
git clone https://github.com/Christian-SC26/factorio-mod-manager.git
cd factorio-mod-manager/FactorioModManagerMac
./build_app.sh
open FMM.app
```

With the full Xcode installed, the script builds a universal app (Apple Silicon and Intel). With the Command Line Tools only, it builds for your Mac's own architecture, which also works on Intel. Run the tests with `swift test`.

## License

[MIT](LICENSE).
