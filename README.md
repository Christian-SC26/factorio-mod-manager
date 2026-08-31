# Factorio Mod Manager (FMM)

Fast, lightweight CLI and interactive mod manager for Factorio (2.1, 2.0, 1.1) with dependency resolution and mirror downloads.

## Usage

Run `fmm` in your terminal  

## Installation

macOS / Linux / Steam Deck

- One-line installation **(Recommended)**:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/Christian-SC26/factorio-mod-manager/main/install.sh | bash
  ```
  > Installs to `~/.local/share/factorio-mod-manager` and links `fmm` to `~/.local/bin/fmm`.  

- Homebrew (macOS / Linux):

  ```bash
  brew install https://raw.githubusercontent.com/Christian-SC26/factorio-mod-manager/main/Formula/fmm.rb
  ```

Windows (PowerShell / CMD)

- PowerShell one-line installer **(Recommended)**:

  ```powershell
  irm https://raw.githubusercontent.com/Christian-SC26/factorio-mod-manager/main/install.ps1 | iex
  ```
  > Installs to `%LOCALAPPDATA%\factorio-mod-manager` and adds `fmm` to your user PATH.  

- Manual Windows installation:

  1 - Download repository ZIP or clone:
   ```cmd
   git clone https://github.com/Christian-SC26/factorio-mod-manager.git %LOCALAPPDATA%\factorio-mod-manager
   ```
  2 - Run `fmm.cmd` directly or add folder to your PATH.

Python pipx / pip (Cross-platform)

  ```bash
  # Using pipx (isolated environment)
  pipx install git+https://github.com/Christian-SC26/factorio-mod-manager.git

  # Using standard pip
  pip install git+https://github.com/Christian-SC26/factorio-mod-manager.git
  ```

## Features

- **Direct Mirror Downloads**: Downloads mods directly from cloud storage mirror without factorio.com account.  
- **Instant Profile Switching**: Switch between whole modpacks (`space-age`, `pyanodons`, `krastorio2`, etc.) in 0.01s without re-downloading files.  
- **Deep Dependency Resolution**: Recursively resolves required, recommended (+), load order (~), and optional (?) dependencies, with conflict detection (!).  
- **Factorio 2.1 / 2.0 / 1.1 Support**: Automatically detects exact installed game version (e.g. 2.1.17, 2.0.x, 1.1.x) or defaults to latest 2.1 mod releases.  
- **Full mod-list.json Management**: Auto-enables installed mods, cleans old versions, and checks for updates.  
- **Export & Import**: Export modpacks to shareable JSON/text files to install anywhere.  
- **Interactive TUI**: Convenient terminal menu structured into 4 visual categories with multi-selection, search, and language toggle (English / Russian).  
- **Zero External Dependencies**: Pure Python 3.8+ using only standard library.  

## Quick Start

Run the interactive menu or use CLI commands:  

```bash
# Launch interactive menu (press 'Q' to exit, 'L' to toggle language)
fmm

# Download a mod or modpack by portal URL with all dependencies
fmm install https://mods.factorio.com/mod/space-exploration

# Download by mod name
fmm install Krastorio2

# Download multiple mods at once (space-separated, glued URLs, or multiline paste)
fmm install Krastorio2 flib alien-biomes

# List installed mods
fmm list

# Check for updates
fmm check

# Update all installed mods
fmm update

# Browse & download optional mods for installed mods
fmm optional

# Browse and install mods by author / creator
fmm author Earendel

# Search mods by keyword in title or description (e.g. mulana, train, space)
fmm search mulana
fmm search train --v2

# Switch language to English or Russian
fmm lang en
fmm lang ru
```

## Profiles & Quick Switching

Profiles allow you to maintain multiple separate game setups simultaneously on the same machine:  

```bash
# View saved profiles
fmm profiles

# Switch to Pyanodons
fmm switch pyanodons

# Switch to Space Age
fmm switch space-age

# Save current enabled mod set as a new profile
fmm profile save my-pack
```

## Export & Import Modpacks

Export your active mod list to a file to share with friends, and import on any computer:  

```bash
# Export active mods to a file
fmm export my_modpack.json

# Import and download all missing mods with dependencies
fmm import my_modpack.json
```

## CLI Reference

```
usage: fmm [-h] [-d MODS_DIR] [-v FACTORIO_VERSION] [-l {en,ru}]
           {install,author,search,switch,profiles,profile,list,check,update,info,optional,enable,disable,remove,export,import,lang,interactive} ...

Options:

  -d, --dir PATH                Path to Factorio mods directory (auto-detected by default)
                                
  -v, --factorio-version VER    Target Factorio branch (e.g. 2.1, 2.0, 1.1)
                                
  -l, --lang {en,ru}            Interface language: en (English) or ru (Russian)
                                

Install Flags:

  --no-recommended             Do not download recommended '+' dependencies
                                
  --optional                   Download optional '?' dependencies
                                
  -f, --force                  Force reinstall even if version matches
                                
  -y, --yes                    Automatically confirm download prompts
                                
  --no-clean                   Do not remove older versions of updated mods
                                
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
