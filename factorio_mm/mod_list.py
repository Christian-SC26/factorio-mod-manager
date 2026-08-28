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

from .version import FactorioVersion


@dataclass
class LocalMod:
    name: str
    version: FactorioVersion
    file_path: Path
    is_directory: bool
    enabled: bool = True
    info_json: Dict = field(default_factory=dict)

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
    """Try to detect installed Factorio version from parent directories or logs."""
    factorio_dir = mods_dir.parent
    
    log_file = factorio_dir / "factorio-current.log"
    if log_file.exists():
        try:
            with open(log_file, "r", encoding="utf-8", errors="ignore") as f:
                for _ in range(30):
                    line = f.readline()
                    if not line:
                        break
                    m = re.search(r"Factorio\s+(?:initialised|version)?\s*(\d+\.\d+(?:\.\d+)?)", line, re.I)
                    if m:
                        return m.group(1)
        except Exception:
            pass

    base_info = factorio_dir / "data" / "base" / "info.json"
    if base_info.exists():
        try:
            with open(base_info, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("version")
        except Exception:
            pass

    return None


class ModListManager:
    """Manages reading, writing, modifying mod-list.json, scanning local mods, and profiles."""

    def __init__(self, mods_dir: Optional[Path] = None):
        self.mods_dir = (mods_dir or get_default_factorio_mods_dir()).expanduser().resolve()
        self.mod_list_file = self.mods_dir / "mod-list.json"
        self.profiles_dir = self.mods_dir / ".fmm_profiles"

    def ensure_mods_dir(self):
        """Create mods directory if it doesn't exist."""
        self.mods_dir.mkdir(parents=True, exist_ok=True)
        self.profiles_dir.mkdir(parents=True, exist_ok=True)

    def read_mod_list_json(self) -> Dict:
        """Read mod-list.json or return default structure."""
        if not self.mod_list_file.exists():
            return {
                "mods": [
                    {"name": "base", "enabled": True}
                ]
            }

        try:
            with open(self.mod_list_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {"mods": [{"name": "base", "enabled": True}]}

    def write_mod_list_json(self, data: Dict):
        """Save mod-list.json safely."""
        self.ensure_mods_dir()
        temp_file = self.mod_list_file.with_suffix(".json.tmp")
        with open(temp_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        temp_file.replace(self.mod_list_file)

    def scan_installed_mods(self) -> Dict[str, List[LocalMod]]:
        """
        Scan all installed mods in the mods folder.
        Returns a dict mapping mod_name -> list of LocalMod (ordered by version).
        """
        if not self.mods_dir.exists():
            return {}

        list_json = self.read_mod_list_json()
        enabled_map: Dict[str, bool] = {}
        for item in list_json.get("mods", []):
            if isinstance(item, dict) and "name" in item:
                enabled_map[item["name"]] = item.get("enabled", True)

        found_mods: Dict[str, List[LocalMod]] = {}

        for entry in self.mods_dir.iterdir():
            if entry.name.startswith(".") or entry.name == "mod-list.json" or entry.name.endswith(".tmp"):
                continue

            mod_name = None
            version_str = None
            info_json = {}

            if entry.is_file() and entry.suffix.lower() == ".zip":
                m = re.match(r"^(.+)_(\d+(?:\.\d+)*)\.zip$", entry.name, re.I)
                if m:
                    mod_name = m.group(1)
                    version_str = m.group(2)
                else:
                    try:
                        with zipfile.ZipFile(entry, "r") as z:
                            for name in z.namelist():
                                if name.endswith("info.json"):
                                    with z.open(name) as jf:
                                        info_json = json.load(jf)
                                        mod_name = info_json.get("name")
                                        version_str = info_json.get("version")
                                        break
                    except Exception:
                        pass

            elif entry.is_dir():
                info_path = entry / "info.json"
                if info_path.exists():
                    try:
                        with open(info_path, "r", encoding="utf-8") as f:
                            info_json = json.load(f)
                            mod_name = info_json.get("name")
                            version_str = info_json.get("version")
                    except Exception:
                        pass

                if not mod_name:
                    m = re.match(r"^(.+)_(\d+(?:\.\d+)*)$", entry.name)
                    if m:
                        mod_name = m.group(1)
                        version_str = m.group(2)

            if mod_name and version_str:
                is_enabled = enabled_map.get(mod_name, True)
                local_mod = LocalMod(
                    name=mod_name,
                    version=FactorioVersion(version_str),
                    file_path=entry,
                    is_directory=entry.is_dir(),
                    enabled=is_enabled,
                    info_json=info_json,
                )
                if mod_name not in found_mods:
                    found_mods[mod_name] = []
                found_mods[mod_name].append(local_mod)

        for mod_name in found_mods:
            found_mods[mod_name].sort(key=lambda m: m.version)

        return found_mods

    def set_mod_state(self, mod_name: str, enabled: bool):
        """Enable or disable a mod in mod-list.json."""
        data = self.read_mod_list_json()
        mods_list = data.get("mods", [])
        
        found = False
        for item in mods_list:
            if isinstance(item, dict) and item.get("name") == mod_name:
                item["enabled"] = enabled
                found = True
                break

        if not found:
            mods_list.append({"name": mod_name, "enabled": enabled})

        data["mods"] = mods_list
        self.write_mod_list_json(data)

    def enable_mods(self, mod_names: List[str]):
        """Enable multiple mods in mod-list.json."""
        data = self.read_mod_list_json()
        mods_list = data.get("mods", [])
        existing_names = {item.get("name") for item in mods_list if isinstance(item, dict)}

        for item in mods_list:
            if isinstance(item, dict) and item.get("name") in mod_names:
                item["enabled"] = True

        for name in mod_names:
            if name not in existing_names and name.lower() != "base":
                mods_list.append({"name": name, "enabled": True})

        data["mods"] = mods_list
        self.write_mod_list_json(data)

    def remove_mod(self, mod_name: str, delete_files: bool = True) -> int:
        """Remove a mod from mod-list.json and optionally delete files."""
        data = self.read_mod_list_json()
        data["mods"] = [item for item in data.get("mods", []) if item.get("name") != mod_name]
        self.write_mod_list_json(data)

        deleted_count = 0
        if delete_files:
            installed = self.scan_installed_mods()
            if mod_name in installed:
                for local_mod in installed[mod_name]:
                    try:
                        if local_mod.file_path.is_file():
                            local_mod.file_path.unlink()
                            deleted_count += 1
                        elif local_mod.file_path.is_dir():
                            import shutil
                            shutil.rmtree(local_mod.file_path)
                            deleted_count += 1
                    except Exception as e:
                        print(f"Error removing {local_mod.file_path}: {e}", file=sys.stderr)
        return deleted_count

    # ----------------- PROFILES / PRESETS -----------------

    def save_profile(self, profile_name: str) -> Path:
        """Save currently enabled mods as a named profile."""
        self.ensure_mods_dir()
        profile_file = self.profiles_dir / f"{profile_name}.json"
        
        current_data = self.read_mod_list_json()
        with open(profile_file, "w", encoding="utf-8") as f:
            json.dump(current_data, f, indent=2, ensure_ascii=False)
        return profile_file

    def list_profiles(self) -> List[Tuple[str, int, bool]]:
        """List all saved profiles: (name, enabled_mod_count, is_current)."""
        self.ensure_mods_dir()
        profiles = []
        current_data = self.read_mod_list_json()
        current_enabled = {
            item["name"] for item in current_data.get("mods", [])
            if isinstance(item, dict) and item.get("enabled", True)
        }

        for file in sorted(self.profiles_dir.glob("*.json")):
            try:
                with open(file, "r", encoding="utf-8") as f:
                    p_data = json.load(f)
                    p_enabled = {
                        item["name"] for item in p_data.get("mods", [])
                        if isinstance(item, dict) and item.get("enabled", True)
                    }
                    is_active = (p_enabled == current_enabled)
                    profiles.append((file.stem, len(p_enabled), is_active))
            except Exception:
                pass
        return profiles

    def apply_profile(self, profile_name: str) -> Tuple[bool, str, List[str]]:
        """
        Switch active mods to match the saved profile.
        All mods in the profile become enabled, others disabled.
        Returns (success, message, missing_mods_list).
        """
        self.ensure_mods_dir()
        profile_file = self.profiles_dir / f"{profile_name}.json"
        if not profile_file.exists():
            return False, f"Профиль '{profile_name}' не найден", []

        try:
            with open(profile_file, "r", encoding="utf-8") as f:
                target_data = json.load(f)
        except Exception as e:
            return False, f"Ошибка чтения профиля: {e}", []

        # Write directly to mod-list.json
        self.write_mod_list_json(target_data)

        # Check if any enabled mods are physically missing from disk
        installed = self.scan_installed_mods()
        missing = []
        for item in target_data.get("mods", []):
            if isinstance(item, dict) and item.get("enabled", True):
                mod_name = item.get("name")
                if mod_name not in ("base", "quality", "space-age", "elevated-rails", "recycler"):
                    if mod_name not in installed:
                        missing.append(mod_name)

        return True, f"Профиль '{profile_name}' успешно активирован!", missing

    def delete_profile(self, profile_name: str) -> bool:
        """Delete a saved profile."""
        profile_file = self.profiles_dir / f"{profile_name}.json"
        if profile_file.exists():
            profile_file.unlink()
            return True
        return False
