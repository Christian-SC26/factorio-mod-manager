"""Factorio mod folder and mod-list.json management."""

from __future__ import annotations
import json
import os
import platform
import re
import sys
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

from .i18n import i18n
from .version import Dependency, FactorioVersion


@dataclass
class LocalMod:
    name: str
    version: FactorioVersion
    file_path: Path
    is_directory: bool
    enabled: bool = True
    info_json: Dict = field(default_factory=dict)

    def get_info_json(self) -> Dict:
        """Load and cache the full info.json dict from the archive or directory."""
        if self.info_json:
            return self.info_json
        if self.file_path.is_file() and self.file_path.suffix.lower() == ".zip":
            try:
                with zipfile.ZipFile(self.file_path, "r") as z:
                    for zname in z.namelist():
                        if zname.endswith("info.json"):
                            with z.open(zname) as jf:
                                self.info_json = json.load(jf)
                            break
            except Exception:
                pass
        elif self.file_path.is_dir():
            info_p = self.file_path / "info.json"
            if info_p.exists():
                try:
                    with open(info_p, "r", encoding="utf-8") as jf:
                        self.info_json = json.load(jf)
                except Exception:
                    pass
        return self.info_json

    def get_dependencies(self) -> List[Dependency]:
        """Read and parse dependencies directly from the local archive or directory info.json."""
        info = self.get_info_json()
        raw_deps = info.get("dependencies", [])
        result = []
        for d in raw_deps:
            parsed = Dependency.parse(d)
            if parsed:
                result.append(parsed)
        return result

    def __repr__(self) -> str:
        status = "enabled" if self.enabled else "disabled"
        return f"<LocalMod {self.name} v{self.version} [{status}] ({self.file_path.name})>"


def get_default_factorio_mods_dir() -> Path:
    """Find default Factorio mods directory based on OS."""
    env_custom = os.environ.get("FACTORIO_MODS_DIR")
    if env_custom:
        return Path(env_custom).expanduser().resolve()

    system = platform.system().lower()
    home = Path.home()

    if system == "darwin":  # macOS
        standard_path = home / "Library" / "Application Support" / "factorio" / "mods"
        if (home / "Library" / "Application Support" / "factorio").exists() or standard_path.exists():
            return standard_path

    elif system == "windows":
        appdata = os.environ.get("APPDATA")
        if appdata:
            win_path = Path(appdata) / "Factorio" / "mods"
            return win_path
        return home / "AppData" / "Roaming" / "Factorio" / "mods"

    else:  # Linux / BSD / SteamOS
        p1 = home / ".factorio" / "mods"
        if p1.parent.exists():
            return p1
        p2 = home / ".local" / "share" / "factorio" / "mods"
        if p2.parent.exists():
            return p2
        return p1

    return Path.cwd() / "mods"


def detect_installed_factorio_version(mods_dir: Path) -> Optional[str]:
    """Try to detect the exact installed Factorio version from logs, app bundles, or base data."""
    factorio_dir = mods_dir.parent
    log_candidates = [
        factorio_dir / "factorio-current.log",
        factorio_dir / "factorio-previous.log",
        factorio_dir / "config" / "factorio-current.log",
    ]

    for log_path in log_candidates:
        if log_path.exists():
            try:
                with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
                    for _ in range(50):
                        line = f.readline()
                        if not line:
                            break
                        # Factorio 2.x log format: "0.000 2026-08-29 ...; Factorio 2.1.17 (build 87315..."
                        m = re.search(r"Factorio\s+(\d+\.\d+\.\d+)", line, re.I)
                        if m:
                            return m.group(1)
                        m2 = re.search(r"Loading\s+mod\s+(?:base|core)\s+(\d+\.\d+\.\d+)", line, re.I)
                        if m2:
                            return m2.group(1)
            except Exception:
                pass

    # Check macOS app bundles
    app_candidates = [
        Path("/Applications/factorio.app"),
        Path.home() / "Applications" / "factorio.app",
        Path.home() / "Library/Application Support/Steam/steamapps/common/Factorio/factorio.app",
    ]
    for app in app_candidates:
        plist_path = app / "Contents" / "Info.plist"
        if plist_path.exists():
            try:
                import plistlib
                with open(plist_path, "rb") as f:
                    pl = plistlib.load(f)
                    v = pl.get("CFBundleShortVersionString") or pl.get("CFBundleVersion")
                    if v:
                        return str(v).strip()
            except Exception:
                pass

    # Check base info.json in standard Steam and install locations
    base_candidates = [
        Path("/Applications/factorio.app/Contents/data/base/info.json"),
        Path.home() / ".steam/steam/steamapps/common/Factorio/data/base/info.json",
        Path.home() / ".local/share/Steam/steamapps/common/Factorio/data/base/info.json",
        Path("C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/base/info.json"),
        Path("C:/Program Files/Factorio/data/base/info.json"),
    ]
    for bc in base_candidates:
        if bc.exists():
            try:
                with open(bc, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if data.get("version"):
                        return str(data["version"]).strip()
            except Exception:
                pass

    return "2.1"


class ModListManager:
    """Manages the factorio mods directory and mod-list.json file."""

    def __init__(self, mods_dir: Optional[Path] = None):
        self.mods_dir = mods_dir or get_default_factorio_mods_dir()
        self.mod_list_json_path = self.mods_dir / "mod-list.json"
        self._ensure_dir()

    def _ensure_dir(self):
        self.mods_dir.mkdir(parents=True, exist_ok=True)

    def read_mod_list_json(self) -> Dict[str, bool]:
        """Read mod-list.json and return a dictionary of {mod_name: enabled_bool}."""
        if not self.mod_list_json_path.exists():
            return {"base": True}

        try:
            with open(self.mod_list_json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                mods = data.get("mods", [])
                result = {}
                for m in mods:
                    name = m.get("name")
                    enabled = m.get("enabled", True)
                    if name:
                        result[name] = enabled
                if "base" not in result:
                    result["base"] = True
                return result
        except Exception:
            return {"base": True}

    def write_mod_list_json(self, mod_states: Dict[str, bool]) -> None:
        """Write mod states back to mod-list.json preserving standard format."""
        self._ensure_dir()
        if "base" not in mod_states:
            mod_states["base"] = True

        mods_list = [{"name": name, "enabled": enabled} for name, enabled in sorted(mod_states.items())]
        base_item = next((m for m in mods_list if m["name"] == "base"), None)
        if base_item:
            mods_list.remove(base_item)
            mods_list.insert(0, base_item)

        data = {"mods": mods_list}
        tmp_path = self.mod_list_json_path.with_suffix(".tmp")
        with open(tmp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        tmp_path.replace(self.mod_list_json_path)

    def scan_installed_mods(self) -> Dict[str, List[LocalMod]]:
        """
        Scan mods directory for .zip files and directories.
        Returns {mod_name: [LocalMod, ...]}.
        """
        self._ensure_dir()
        states = self.read_mod_list_json()
        installed: Dict[str, List[LocalMod]] = {}

        if not self.mods_dir.exists():
            return installed

        for entry in self.mods_dir.iterdir():
            if entry.name.startswith(".") or entry.name == "mod-list.json" or entry.name.endswith(".tmp"):
                continue

            mod_name = None
            version_str = None
            is_dir = entry.is_dir()

            if is_dir:
                info_file = entry / "info.json"
                if info_file.exists():
                    try:
                        with open(info_file, "r", encoding="utf-8") as f:
                            info_data = json.load(f)
                            mod_name = info_data.get("name")
                            version_str = info_data.get("version")
                    except Exception:
                        pass
                if not mod_name:
                    m = re.match(r"^([^_]+)_(.+)$", entry.name)
                    if m:
                        mod_name, version_str = m.groups()
                    else:
                        mod_name = entry.name
                        version_str = "0.0.1"

            elif entry.is_file() and entry.suffix.lower() == ".zip":
                m = re.match(r"^(.+)_(\d+(?:\.\d+)*)\.zip$", entry.name, re.I)
                if m:
                    mod_name, version_str = m.groups()
                else:
                    try:
                        with zipfile.ZipFile(entry, "r") as z:
                            for zname in z.namelist():
                                if zname.endswith("info.json"):
                                    with z.open(zname) as jf:
                                        info_data = json.load(jf)
                                        mod_name = info_data.get("name")
                                        version_str = info_data.get("version")
                                    break
                    except Exception:
                        pass

            if mod_name and version_str:
                enabled = states.get(mod_name, True)
                local_mod = LocalMod(
                    name=mod_name,
                    version=FactorioVersion(version_str),
                    file_path=entry,
                    is_directory=is_dir,
                    enabled=enabled,
                )
                if mod_name not in installed:
                    installed[mod_name] = []
                installed[mod_name].append(local_mod)

        for name in installed:
            installed[name].sort(key=lambda m: m.version, reverse=True)

        return installed

    def enable_mods(self, mod_names: List[str]) -> None:
        """Enable specified mods in mod-list.json."""
        states = self.read_mod_list_json()
        for name in mod_names:
            states[name] = True
        self.write_mod_list_json(states)

    def disable_mods(self, mod_names: List[str]) -> None:
        """Disable specified mods in mod-list.json."""
        states = self.read_mod_list_json()
        for name in mod_names:
            if name != "base":
                states[name] = False
        self.write_mod_list_json(states)

    def toggle_mod(self, mod_name: str) -> bool:
        """Toggle mod enabled status. Returns new state."""
        states = self.read_mod_list_json()
        current = states.get(mod_name, True)
        new_state = not current
        states[mod_name] = new_state
        self.write_mod_list_json(states)
        return new_state

    def remove_mod(self, mod_name: str) -> int:
        """Remove all files and folders associated with mod_name."""
        installed = self.scan_installed_mods()
        removed_count = 0
        if mod_name in installed:
            for local_mod in installed[mod_name]:
                try:
                    if local_mod.is_directory:
                        import shutil
                        shutil.rmtree(local_mod.file_path)
                    else:
                        local_mod.file_path.unlink(missing_ok=True)
                    removed_count += 1
                except Exception as e:
                    print(f"[!] Failed to delete {local_mod.file_path}: {e}")

        states = self.read_mod_list_json()
        if mod_name in states:
            del states[mod_name]
            self.write_mod_list_json(states)

        return removed_count

    def get_profiles_dir(self) -> Path:
        p = self.mods_dir / ".fmm_profiles"
        p.mkdir(parents=True, exist_ok=True)
        return p

    def save_profile(self, profile_name: str) -> Path:
        """Save current active mods and versions as a named profile."""
        clean_name = re.sub(r"[^\w\.-]", "_", profile_name.strip())
        if not clean_name:
            clean_name = "default"

        states = self.read_mod_list_json()
        installed = self.scan_installed_mods()

        active_mods: Dict[str, str] = {}
        for name, is_enabled in states.items():
            if is_enabled and name != "base":
                if name in installed and installed[name]:
                    active_mods[name] = str(installed[name][0].version)
                else:
                    active_mods[name] = "latest"

        profile_data = {
            "name": clean_name,
            "factorio_version": detect_installed_factorio_version(self.mods_dir),
            "mods": active_mods,
            "all_states": states,
        }

        profile_file = self.get_profiles_dir() / f"{clean_name}.json"
        with open(profile_file, "w", encoding="utf-8") as f:
            json.dump(profile_data, f, indent=2, ensure_ascii=False)
            f.write("\n")

        return profile_file

    def list_profiles(self) -> List[Dict]:
        """List all saved profiles."""
        p_dir = self.get_profiles_dir()
        profiles = []
        for pf in sorted(p_dir.glob("*.json")):
            try:
                with open(pf, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    profiles.append(data)
            except Exception:
                pass
        return profiles

    def load_profile(self, profile_name: str) -> Tuple[bool, List[str], List[str]]:
        """
        Load a profile: enables all mods from profile, disables others.
        Returns (success, activated_mods, missing_mods_to_download).
        """
        clean_name = re.sub(r"[^\w\.-]", "_", profile_name.strip())
        profile_file = self.get_profiles_dir() / f"{clean_name}.json"
        if not profile_file.exists():
            return False, [], []

        with open(profile_file, "r", encoding="utf-8") as f:
            data = json.load(f)

        profile_mods: Dict[str, str] = data.get("mods", {})
        installed = self.scan_installed_mods()

        new_states = {"base": True}
        for name in installed:
            new_states[name] = False

        missing_mods = []
        activated_mods = []

        for mod_name in profile_mods:
            if mod_name in installed:
                new_states[mod_name] = True
                activated_mods.append(mod_name)
            else:
                missing_mods.append(mod_name)
                new_states[mod_name] = True

        self.write_mod_list_json(new_states)
        return True, activated_mods, missing_mods

    def export_modpack(self, out_path: Path) -> int:
        """Export list of active mods to a JSON file."""
        states = self.read_mod_list_json()
        installed = self.scan_installed_mods()

        modpack_entries = []
        for name, enabled in states.items():
            if enabled and name != "base":
                ver = str(installed[name][0].version) if name in installed else "latest"
                modpack_entries.append({"name": name, "version": ver})

        data = {
            "factorio_version": detect_installed_factorio_version(self.mods_dir),
            "mods": modpack_entries,
        }

        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")

        return len(modpack_entries)

    def import_modpack(self, in_path: Path) -> List[Tuple[str, Optional[str]]]:
        """Import modpack JSON and return list of (mod_name, version_spec)."""
        with open(in_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        raw_mods = data.get("mods", [])
        result = []
        for item in raw_mods:
            if isinstance(item, str):
                result.append((item, None))
            elif isinstance(item, dict):
                m_name = item.get("name")
                m_ver = item.get("version")
                if m_name:
                    ver_spec = m_ver if m_ver and m_ver != "latest" else None
                    result.append((m_name, ver_spec))
        return result
