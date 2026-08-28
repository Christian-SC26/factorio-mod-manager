# Factorio Mod Manager (FMM)

A fast, lightweight, zero-dependency command-line and interactive mod manager for **Factorio (2.1, 2.0, 1.1)** with automatic dependency resolution and fast mirror downloads.

---

## Features

- **Direct Mirror Downloads**: Download mods and modpacks directly without requiring factorio.com credentials.
- **Instant Profile Switching**: Save and switch between complete modpacks (`space-age`, `pyanodons`, `krastorio2`, etc.) in 0.01 seconds without re-downloading files.
- **Deep Dependency Resolution**: Recursively resolves required, order-independent, recommended, and optional dependencies with version constraint solving and conflict detection.
- **Factorio 2.1 / 2.0 / 1.1 Support**: Defaults to the latest 2.1 mod releases or detects your installed game version.
- **Mod List & Update Management**: Cleanly manages `mod-list.json`, checks for updates, and upgrades outdated mods in batch.
- **Export & Import**: Export full modpack configurations to shareable JSON/text files and install them on other machines.
- **Clean Interactive TUI**: Terminal menu with bilingual support (English / Russian) and clean ASCII formatting.
- **Zero External Dependencies**: Pure Python 3.8+ using only the standard library.

---

## Quick Start

The tool is installed and available globally as `fmm`:

```bash
# Install a mod or modpack with all dependencies
fmm install https://mods.factorio.com/mod/space-exploration

# Switch to English / Russian
fmm lang en
fmm lang ru

# Switch between mod profiles instantly
fmm switch pyanodons
fmm switch space-age

# List installed mods
fmm list

# Check for updates
fmm check

# Update all mods
fmm update

# Launch interactive menu (press 'q' to exit, 'L' to switch language)
fmm
```

---

## Profile Management

Profiles allow you to maintain multiple separate game setups simultaneously:

```bash
# View saved profiles
fmm profiles

# Switch to a profile
fmm switch pyanodons
fmm switch space-age

# Save current enabled mod set as a new profile
fmm profile save krastorio2
```

---

## CLI Options

```
usage: fmm [-h] [-d MODS_DIR] [-v FACTORIO_VERSION] [-l {en,ru}] {install,switch,profiles,profile,list,check,update,info,enable,disable,remove,export,import,lang,interactive} ...

Options:
  -d, --dir PATH                Path to Factorio mods directory (auto-detected by default)
  -v, --factorio-version VER    Target Factorio version branch (e.g. 2.1, 2.0, 1.1)
  -l, --lang {en,ru}            Interface language (English or Russian)

Install Flags:
  --no-recommended             Do not download recommended '+' dependencies
  --optional                   Download optional '?' dependencies
  -f, --force                  Force reinstall even if already installed
  -y, --yes                    Automatically confirm download prompts
  --no-clean                   Do not remove older versions of updated mods
```
