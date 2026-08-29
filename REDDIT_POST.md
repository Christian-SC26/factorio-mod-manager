# Reddit Post Draft for r/factorio

**Subreddit:** r/factorio  
**Recommended Flair:** `Mod / Tool`

---

## Post Title Options

- **Option 1 (Direct & Informative - Recommended):**  
  `[Tool] Factorio Mod Manager (fmm): Fast CLI/TUI for modpacks, instant profile switching, and recursive dependency resolution`

- **Option 2 (Community-focused):**  
  `I built a zero-dependency CLI & TUI mod manager for Factorio (instant profile switching, recursive dependencies, mirror downloads)`

---

## Post Body (Copy & Paste to Reddit)

```markdown
Hi everyone,

I built **Factorio Mod Manager (`fmm`)**, an open-source command-line and interactive terminal tool for managing Factorio mods, handling deep dependency trees, and switching between overhaul modpacks.

I frequently switch between different overhaul setups (Space Age, Pyanodons, Krastorio 2, Space Exploration) and wanted a tool that handles full modpack installs with dozens of nested dependencies without manual clicking or third-party desktop app bloat.

### GitHub Repository
👉 **[github.com/Christian-SC26/factorio-mod-manager](https://github.com/Christian-SC26/factorio-mod-manager)**

---

### What it does

- **Instant Profile Switching:** Save active mod setups as profiles (`space-age`, `pyanodons`, `k2so`, etc.) and switch between them in 0.01s. It toggles your `mod-list.json` in place without re-downloading files.
- **Deep Recursive Dependency Resolution:** Resolves required dependencies, recommended (`+`), load order (`~`), and optional (`?`) mods across any tree depth, and flags version conflicts (`!`).
- **Interactive TUI & Full CLI:** Run `fmm` for an interactive terminal menu with space-separated multi-selection, or use direct CLI commands like `fmm install <url/name>`.
- **Search & Author Browsing:** Search mods by keyword in title/description (`fmm search <query>`) or browse all mods published by a specific creator (`fmm author <name>`).
- **Export & Import Modpacks:** Export your current mod list to a `.json` file to share with friends, and import it on any machine to pull missing mods automatically.
- **Mirror Downloads:** Downloads mods directly from cloud mirror without requiring factorio.com credentials in the tool.
- **Zero External Dependencies:** Built with pure Python 3.8+ standard library. No `pip` packages required.
- **Cross-Platform:** Works on macOS, Linux, Steam Deck, and Windows. Automatically detects your game path and installed Factorio version (2.1.x, 2.0.x, 1.1.x).

---

### Quick Installation

**macOS / Linux / Steam Deck (One-line installer):**
```bash
curl -fsSL https://raw.githubusercontent.com/Christian-SC26/factorio-mod-manager/main/install.sh | bash
```

**Homebrew (macOS / Linux):**
```bash
brew install https://raw.githubusercontent.com/Christian-SC26/factorio-mod-manager/main/Formula/fmm.rb
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/Christian-SC26/factorio-mod-manager/main/install.ps1 | iex
```

**Python pip / pipx (Cross-platform):**
```bash
pip install git+https://github.com/Christian-SC26/factorio-mod-manager.git
```

---

### Quick Examples

```bash
# Launch interactive menu
fmm

# Install a modpack with all dependencies
fmm install https://mods.factorio.com/mod/space-exploration

# Install multiple mods at once
fmm install Krastorio2 flib alien-biomes

# Save current setup as a profile
fmm profile save space-age

# Switch between modpack profiles
fmm switch pyanodons
fmm switch space-age

# Search mods by keyword
fmm search mulana --v2

# Browse mods by author
fmm author Earendel

# Export and import modpacks
fmm export my-pack.json
fmm import my-pack.json
```

---

The project is open-source under the MIT license. Feedback, feature requests, and bug reports are welcome on GitHub or in the comments!
```
