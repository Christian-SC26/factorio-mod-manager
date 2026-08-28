"""CLI and interactive interface for Factorio Mod Manager."""

from __future__ import annotations
import argparse
import json
import os
import re
import sys
import unicodedata
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import readline
except ImportError:
    pass

from .api import (
    ModPortalClient,
    SearchModItem,
    fetch_author_mods,
    parse_mod_input,
    search_portal_mods,
)
from .downloader import ModDownloader, format_bytes
from .i18n import i18n
from .mod_list import (
    ModListManager,
    detect_installed_factorio_version,
    get_default_factorio_mods_dir,
)
from .resolver import DependencyResolver, ResolutionResult
from .version import Dependency, DependencyType, FactorioVersion


# ANSI Color Codes for terminal formatting
class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RESET = "\033[0m"


def print_banner():
    title = i18n.t("banner_title")
    subtitle = i18n.t("banner_subtitle")
    inner_width = 62
    width = inner_width + 4

    def center_text(txt: str, w: int) -> str:
        vis_len = sum(2 if unicodedata.east_asian_width(c) in ("F", "W") else 1 for c in txt)
        pad = max(0, w - vis_len)
        left = pad // 2
        right = pad - left
        return " " * left + txt + " " * right

    line1 = center_text(title, inner_width)
    line2 = center_text(subtitle, inner_width)
    top = "╔" + "═" * (width - 2) + "╗"
    middle1 = f"║ {line1} ║"
    middle2 = f"║ {line2} ║"
    bottom = "╚" + "═" * (width - 2) + "╝"

    banner = f"\n{Colors.CYAN}{Colors.BOLD}{top}\n{middle1}\n{middle2}\n{bottom}{Colors.RESET}\n"
    print(banner)


def format_tree(graph: dict, roots: list, indent: str = "", visited: set = None) -> list[str]:
    """Generate ASCII dependency tree lines."""
    if visited is None:
        visited = set()
    lines = []
    for i, root in enumerate(roots):
        is_last = (i == len(roots) - 1)
        prefix = "└── " if is_last else "├── "
        lines.append(f"{indent}{prefix}{Colors.BOLD}{root}{Colors.RESET}")
        
        child_indent = indent + ("    " if is_last else "│   ")
        children = graph.get(root, [])
        if children and root not in visited:
            visited.add(root)
            lines.extend(format_tree(graph, children, child_indent, visited))
    return lines


def parse_multi_selection(raw_str: str, item_names: List[str]) -> Optional[List[int]]:
    """
    Parse a user selection string into list of 0-based indices.
    Supports space-separated '1 3 5', '1-4 7', 'all', '*', names, or 'q' to cancel.
    Returns None on cancellation.
    """
    s = raw_str.strip()
    if not s or s.lower() in ("q", "quit", "exit", "cancel", "c", "отмена"):
        return None

    if s.lower() in ("all", "*", "все"):
        return list(range(len(item_names)))

    selected_indices = set()
    parts = re.split(r"[,;\s]+", s)

    for p in parts:
        if not p:
            continue
        # Range check: 1-4 or 1..4
        m_range = re.match(r"^(\d+)[\-\.\:]+(\d+)$", p)
        if m_range:
            start, end = int(m_range.group(1)), int(m_range.group(2))
            for i in range(min(start, end), max(start, end) + 1):
                if 1 <= i <= len(item_names):
                    selected_indices.add(i - 1)
            continue

        # Single number
        if p.isdigit():
            idx = int(p)
            if 1 <= idx <= len(item_names):
                selected_indices.add(idx - 1)
            continue

        # Exact or prefix name match
        matched = False
        for idx, name in enumerate(item_names):
            if p.lower() == name.lower():
                selected_indices.add(idx)
                matched = True
        if not matched:
            for idx, name in enumerate(item_names):
                if p.lower() in name.lower():
                    selected_indices.add(idx)

    return sorted(list(selected_indices))


def read_pasted_input(prompt: str) -> str:
    """Read input from user, seamlessly handling massive single-line and multi-line pastes."""
    line = input(prompt)
    lines = [line]
    if sys.platform != "win32":
        try:
            import select
            while True:
                # Check if more lines are waiting in stdin buffer (e.g. multi-line paste)
                r, _, _ = select.select([sys.stdin], [], [], 0.05)
                if r:
                    extra = sys.stdin.readline()
                    if not extra:
                        break
                    lines.append(extra.strip())
                else:
                    break
        except Exception:
            pass
    return " ".join(lines).strip()


def pause_prompt():
    """Wait for Enter key before returning to menu."""
    try:
        input(f"\n{Colors.DIM}{i18n.t('press_enter')}{Colors.RESET}")
    except (KeyboardInterrupt, EOFError):
        pass


class CLIApp:
    def __init__(
        self,
        mods_dir: Optional[Path] = None,
        factorio_version: Optional[str] = None,
        lang: Optional[str] = None,
    ):
        if lang:
            i18n.set_lang(lang)
        self.mods_dir = mods_dir or get_default_factorio_mods_dir()
        self.mod_list_mgr = ModListManager(self.mods_dir)
        self.client = ModPortalClient()
        self.detected_f_ver = factorio_version or detect_installed_factorio_version(self.mods_dir)

    def print_env_info(self):
        print(f"{Colors.DIM}{i18n.t('mods_dir')}{Colors.RESET} {self.mods_dir}")
        if self.detected_f_ver:
            print(f"{Colors.DIM}{i18n.t('factorio_ver')}{Colors.RESET} {Colors.GREEN}{self.detected_f_ver}{Colors.RESET}")
        else:
            print(f"{Colors.DIM}{i18n.t('factorio_ver')}{Colors.RESET} {Colors.YELLOW}{i18n.t('ver_auto')}{Colors.RESET}")
        print()

    def cmd_install(
        self,
        targets: List[str],
        include_recommended: bool = True,
        include_optional: bool = False,
        force_reinstall: bool = False,
        yes: bool = False,
        clean_old: bool = True,
    ):
        """Resolve and install mods."""
        if not targets:
            print(f"{Colors.RED}[!] No targets specified for installation.{Colors.RESET}")
            return

        opt_status = f" (Optional: {'ON' if include_optional else 'OFF'}, Recommended: {'ON' if include_recommended else 'OFF'})"
        print(f"\n{Colors.CYAN}[*] {i18n.t('resolving_deps', targets=', '.join(targets))}{Colors.RESET}{Colors.DIM}{opt_status}{Colors.RESET}")

        resolver = DependencyResolver(
            client=self.client,
            mod_list_mgr=self.mod_list_mgr,
            target_factorio_branch=self.detected_f_ver,
            include_recommended=include_recommended,
            include_optional=include_optional,
            force_reinstall=force_reinstall,
        )

        res = resolver.resolve(targets)

        # Print Dependency Tree
        if res.dependency_graph:
            print(f"\n{Colors.BOLD}{i18n.t('dep_tree')}{Colors.RESET}")
            tree_lines = format_tree(res.dependency_graph, res.root_mods)
            for line in tree_lines:
                print(line)

        # Print Conflicts
        if res.conflicts:
            print(f"\n{Colors.RED}{Colors.BOLD}[!] {i18n.t('conflicts_found')}{Colors.RESET}")
            for mod_a, mod_b, reason in res.conflicts:
                print(f"  {Colors.RED}* {reason}{Colors.RESET}")

        # Print Warnings / Missing
        if res.missing_mods:
            print(f"\n{Colors.YELLOW}{Colors.BOLD}[!] {i18n.t('missing_mods')}{Colors.RESET}")
            for mod_name, parent in res.missing_mods:
                print(f"  {Colors.YELLOW}* {mod_name} (from: {parent}){Colors.RESET}")

        if res.warnings:
            print(f"\n{Colors.YELLOW}{Colors.BOLD}{i18n.t('warnings')}{Colors.RESET}")
            for w in res.warnings:
                print(f"  {Colors.YELLOW}* {w}{Colors.RESET}")

        # Summary Table
        print(f"\n{Colors.BOLD}{i18n.t('install_plan')}{Colors.RESET}")
        if not res.mods_to_download and not res.mods_up_to_date:
            print("  No mods found for installation.")
            return

        if res.mods_to_download:
            print(f"\n  {Colors.GREEN}{Colors.BOLD}{i18n.t('mods_to_download', count=len(res.mods_to_download))}{Colors.RESET}")
            for mod in res.mods_to_download:
                act_str = "Update" if mod.action == "UPDATE" else "New"
                old_ver = f" (current: v{mod.installed_version})" if mod.installed_version else ""
                rel_ver = f"v{mod.release.version}"
                print(f"    {Colors.GREEN}+{Colors.RESET} {Colors.BOLD}{mod.name}{Colors.RESET} {rel_ver}{old_ver} [{act_str}]")

        if res.mods_up_to_date:
            print(f"\n  {Colors.DIM}{i18n.t('mods_up_to_date', count=len(res.mods_up_to_date))}{Colors.RESET}")
            for mod in res.mods_up_to_date:
                print(f"    {Colors.DIM}* {mod.name} v{mod.release.version}{Colors.RESET}")

        if not res.mods_to_download:
            print(f"\n{Colors.GREEN}{i18n.t('all_up_to_date')}{Colors.RESET}\n")
            return

        # Prompt for confirmation
        if not yes:
            try:
                ans = input(f"\n{Colors.BOLD}{i18n.t('prompt_confirm_download', count=len(res.mods_to_download))}{Colors.RESET}").strip().lower()
                if ans and ans not in ("y", "yes", "д", "да"):
                    print(i18n.t("cancelled"))
                    return
            except (KeyboardInterrupt, EOFError):
                print(f"\n{i18n.t('cancelled')}")
                return

        # Execute download
        downloader = ModDownloader(
            mod_list_mgr=self.mod_list_mgr,
            clean_old=clean_old,
            auto_enable=True,
        )
        results = downloader.download_all(res.mods_to_download)

        success_count = sum(1 for r in results if r.success)
        fail_count = sum(1 for r in results if not r.success)

        if fail_count == 0:
            print(f"\n{Colors.GREEN}{Colors.BOLD}{i18n.t('installed_success', count=success_count)}{Colors.RESET}")
            print(f"{i18n.t('game_ready', path=self.mods_dir)}\n")
        else:
            print(f"\n{Colors.YELLOW}{i18n.t('installed_partial', success=success_count, failed=fail_count)}{Colors.RESET}\n")

    def cmd_list(self):
        """List all installed mods."""
        installed = self.mod_list_mgr.scan_installed_mods()
        if not installed:
            print(f"\n{Colors.YELLOW}{i18n.t('no_mods_found', path=self.mods_dir)}{Colors.RESET}\n")
            return

        print(f"\n{Colors.BOLD}{i18n.t('installed_mods_header', path=self.mods_dir)}{Colors.RESET}\n")
        print(f"{i18n.t('status_col'):<10} {i18n.t('name_col'):<35} {i18n.t('version_col'):<15} {i18n.t('file_col')}")
        print("─" * 80)

        total_mods = 0
        enabled_count = 0

        for name in sorted(installed.keys()):
            for mod in installed[name]:
                total_mods += 1
                if mod.enabled:
                    enabled_count += 1
                    status = f"{Colors.GREEN}{i18n.t('status_enabled')}{Colors.RESET}"
                else:
                    status = f"{Colors.DIM}{i18n.t('status_disabled')}{Colors.RESET}"

                print(f"{status:<19} {Colors.BOLD}{mod.name:<35}{Colors.RESET} {str(mod.version):<15} {mod.file_path.name}")

        print("─" * 80)
        print(i18n.t("total_mods_summary", total=total_mods, enabled=enabled_count, disabled=total_mods - enabled_count) + "\n")

    def cmd_check_updates(self, apply: bool = False, yes: bool = False) -> List[tuple]:
        """Check updates for all installed mods."""
        installed = self.mod_list_mgr.scan_installed_mods()
        if not installed:
            print(f"{Colors.YELLOW}{i18n.t('no_mods_found', path=self.mods_dir)}{Colors.RESET}")
            return []

        print(f"\n[*] {i18n.t('checking_updates', count=len(installed))}\n")
        updates_available: List[tuple] = []

        for name, mod_list in installed.items():
            if name.lower() in ("base", "quality", "space-age", "elevated-rails", "recycler"):
                continue
            latest_local = mod_list[-1]
            try:
                info = self.client.fetch_mod_info(name)
                latest_remote = info.get_latest_release(self.detected_f_ver)
                if latest_remote and latest_remote.version > latest_local.version:
                    updates_available.append((name, latest_local.version, latest_remote.version))
                    print(f"  {Colors.YELLOW}[UPDATE] {name}:{Colors.RESET} {latest_local.version} -> {Colors.GREEN}{latest_remote.version}{Colors.RESET}")
                else:
                    print(f"  {Colors.DIM}[OK] {name} v{latest_local.version}{Colors.RESET}")
            except Exception as e:
                print(f"  {Colors.RED}[!] {name}: error ({e}){Colors.RESET}")

        print()
        if not updates_available:
            print(f"{Colors.GREEN}{i18n.t('all_updates_ok')}{Colors.RESET}\n")
            return []

        print(f"{Colors.BOLD}{i18n.t('updates_count', count=len(updates_available))}{Colors.RESET}")
        if apply:
            mod_names = [u[0] for u in updates_available]
            self.cmd_install(mod_names, yes=yes)
        return updates_available

    def cmd_info(self, target: str):
        """Display detailed info for a mod."""
        name, ver_req, op = parse_mod_input(target)
        if not name:
            print(f"{Colors.RED}[!] No mod name provided.{Colors.RESET}")
            return

        print(f"\n[*] Fetching information for '{name}'...")
        try:
            info = self.client.fetch_mod_info(name)
        except Exception as e:
            print(f"{Colors.RED}[ERROR] {e}{Colors.RESET}")
            return

        print(f"\n{Colors.BOLD}{Colors.CYAN}{info.title}{Colors.RESET} ({Colors.BOLD}{info.name}{Colors.RESET})")
        print(f"{Colors.DIM}{i18n.t('author_label')}{Colors.RESET} {info.owner}  |  {Colors.DIM}{i18n.t('category_label')}{Colors.RESET} {info.category}  |  {Colors.DIM}{i18n.t('downloads_label')}{Colors.RESET} {info.downloads_count:,}")
        if info.summary:
            print(f"\n{Colors.BOLD}{i18n.t('description_label')}{Colors.RESET}\n  {info.summary}\n")

        latest = info.get_latest_release(self.detected_f_ver)
        if latest:
            print(f"{Colors.BOLD}{i18n.t('latest_release_label')}{Colors.RESET} v{latest.version} (Factorio {latest.factorio_version})")
            print(f"{Colors.BOLD}{i18n.t('download_url_label')}{Colors.RESET} {latest.download_url}")
            
            if latest.dependencies:
                print(f"\n{Colors.BOLD}{i18n.t('deps_label', count=len(latest.dependencies))}{Colors.RESET}")
                for dep in latest.dependencies:
                    if dep.dep_type == DependencyType.REQUIRED:
                        tag = f"{Colors.GREEN}{i18n.t('dep_req')}{Colors.RESET}"
                    elif dep.dep_type == DependencyType.RECOMMENDED:
                        tag = f"{Colors.CYAN}{i18n.t('dep_rec')}{Colors.RESET}"
                    elif dep.dep_type == DependencyType.OPTIONAL:
                        tag = f"{Colors.YELLOW}{i18n.t('dep_opt')}{Colors.RESET}"
                    elif dep.dep_type == DependencyType.INCOMPATIBLE:
                        tag = f"{Colors.RED}{i18n.t('dep_conflict')}{Colors.RESET}"
                    else:
                        tag = ""

                    ver_req = f" {dep.op} {dep.version}" if dep.version and dep.op else ""
                    print(f"  * {tag} {dep.name}{ver_req}")
        print()

    def cmd_enable_disable(self, mod_names: List[str], enable: bool):
        """Enable or disable mods in mod-list.json."""
        for name in mod_names:
            self.mod_list_mgr.set_mod_state(name, enable)
            state_str = i18n.t("status_enabled") if enable else i18n.t("status_disabled")
            print(i18n.t("mod_state_changed", name=name, state=state_str))

    def cmd_remove(self, mod_names: List[str]):
        """Remove mods from disk and mod-list.json."""
        total_deleted = 0
        for name in mod_names:
            count = self.mod_list_mgr.remove_mod(name, delete_files=True)
            total_deleted += count
            print(i18n.t("mod_removed", name=name, count=count))
        return total_deleted

    def cmd_export(self, output_file: Optional[str] = None):
        """Export installed mods to JSON or text."""
        installed = self.mod_list_mgr.scan_installed_mods()
        export_data = []
        for name, mod_list in installed.items():
            if name.lower() in ("base", "quality", "space-age", "elevated-rails", "recycler"):
                continue
            latest = mod_list[-1]
            if latest.enabled:
                export_data.append({
                    "name": name,
                    "version": str(latest.version),
                    "url": f"https://mods.factorio.com/mod/{name}"
                })

        target_file = output_file or "modpack.json"
        out_path = Path(target_file)
        if out_path.suffix == ".json":
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(export_data, f, indent=2, ensure_ascii=False)
        else:
            with open(out_path, "w", encoding="utf-8") as f:
                for item in export_data:
                    f.write(f"{item['url']}\n")
        print(f"{Colors.GREEN}{i18n.t('export_success', count=len(export_data), path=target_file)}{Colors.RESET}")

    def cmd_import(self, input_file: str, yes: bool = False, include_optional: bool = False):
        """Import and install mods from a file."""
        in_path = Path(input_file)
        if not in_path.exists():
            print(f"{Colors.RED}[!] {i18n.t('file_not_found', path=input_file)}{Colors.RESET}")
            return

        targets = []
        if in_path.suffix == ".json":
            with open(in_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    for item in data:
                        if isinstance(item, dict) and "name" in item:
                            ver = item.get("version")
                            targets.append(f"{item['name']}=={ver}" if ver else item["name"])
                        elif isinstance(item, str):
                            targets.append(item)
                elif isinstance(data, dict) and "mods" in data:
                    for item in data["mods"]:
                        if isinstance(item, dict) and item.get("enabled", True) and item.get("name") not in ("base", "quality", "space-age", "elevated-rails", "recycler"):
                            targets.append(item["name"])
        else:
            with open(in_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        targets.append(line)

        print(i18n.t("import_start", count=len(targets), path=input_file))
        self.cmd_install(targets, yes=yes, include_optional=include_optional)

    # ----------------- PROFILES / SWITCH -----------------

    def cmd_profile_save(self, name: str):
        """Save current mod setup as a profile."""
        clean_name = name.strip()
        if clean_name.startswith("fmm "):
            clean_name = clean_name.replace("fmm profile save ", "").replace("fmm save ", "").replace("fmm ", "").strip()
        path = self.mod_list_mgr.save_profile(clean_name)
        print(f"{Colors.GREEN}{i18n.t('profile_saved', name=clean_name)}{Colors.RESET}")

    def cmd_profile_list(self) -> List[Tuple[str, int, bool]]:
        """List all profiles."""
        profiles = self.mod_list_mgr.list_profiles()
        if not profiles:
            print(f"{Colors.YELLOW}{i18n.t('no_profiles')}{Colors.RESET}")
            print(f"{i18n.t('create_profile_hint')}\n")
            return []

        print(f"\n{Colors.BOLD}{i18n.t('profiles_header')}{Colors.RESET}\n")
        print(f"{i18n.t('profile_col_num'):<3} {i18n.t('profile_col_status'):<12} {i18n.t('profile_col_name'):<25} {i18n.t('profile_col_mods')}")
        print("─" * 60)
        for idx, (name, count, is_active) in enumerate(profiles, start=1):
            if is_active:
                status = f"{Colors.GREEN}[{i18n.t('profile_active')}]{Colors.RESET}"
            else:
                status = f"{Colors.DIM} {i18n.t('profile_inactive')}{Colors.RESET}"
            print(f"{idx:<3} {status:<21} {Colors.BOLD}{name:<25}{Colors.RESET} {count}")
        print("─" * 60)
        return profiles

    def cmd_profile_switch(self, name_or_index: str):
        """Switch active mods to a profile by name or number."""
        clean_input = name_or_index.strip()
        
        if clean_input.startswith("fmm "):
            clean_input = clean_input.replace("fmm profile switch ", "").replace("fmm switch ", "").replace("fmm load ", "").replace("fmm ", "").strip()
        elif clean_input.startswith("switch "):
            clean_input = clean_input.replace("switch ", "").strip()
        elif clean_input.startswith("load "):
            clean_input = clean_input.replace("load ", "").strip()

        profiles = self.mod_list_mgr.list_profiles()
        if clean_input.isdigit():
            idx = int(clean_input) - 1
            if 0 <= idx < len(profiles):
                clean_input = profiles[idx][0]

        ok, msg, missing = self.mod_list_mgr.apply_profile(clean_input)
        if not ok:
            print(f"{Colors.RED}[!] {i18n.t('profile_not_found', name=clean_input)}{Colors.RESET}")
            return

        print(f"\n{Colors.GREEN}{Colors.BOLD}[OK] {i18n.t('profile_activated', name=clean_input)}{Colors.RESET}")
        if missing:
            print(f"\n{Colors.YELLOW}[!] {i18n.t('profile_missing_mods')}{Colors.RESET}")
            for m in missing:
                print(f"  * {m}")
            ans = input(f"\n{i18n.t('profile_download_missing')}").strip().lower()
            if ans in ("", "y", "yes", "д", "да"):
                self.cmd_install(missing)
        else:
            print(f"{i18n.t('profile_ready')}\n")

    def cmd_profile_delete(self, name: str):
        """Delete a profile."""
        clean_name = name.strip()
        if clean_name.startswith("fmm "):
            clean_name = clean_name.replace("fmm profile delete ", "").replace("fmm profile rm ", "").replace("fmm ", "").strip()
        if self.mod_list_mgr.delete_profile(clean_name):
            print(f"{Colors.GREEN}{i18n.t('profile_deleted', name=clean_name)}{Colors.RESET}")
        else:
            print(f"{Colors.RED}[!] {i18n.t('profile_not_found', name=clean_name)}{Colors.RESET}")

    # ----------------- TUI INTERACTIVE HELPERS -----------------

    def _interactive_mod_info(self):
        """Interactive mod information screen."""
        installed = self.mod_list_mgr.scan_installed_mods()
        mod_names = sorted(installed.keys())

        if mod_names:
            print(f"\n{Colors.BOLD}Installed mods:{Colors.RESET}")
            for idx, name in enumerate(mod_names, start=1):
                mod = installed[name][-1]
                print(f"  {Colors.CYAN}{idx:>2}){Colors.RESET} {Colors.BOLD}{name:<32}{Colors.RESET} v{mod.version}")
            print()

        raw = input(f"{Colors.BOLD}{i18n.t('prompt_mod_info_target')}{Colors.RESET}").strip()
        if not raw or raw.lower() in ("q", "quit", "cancel", "c"):
            print(i18n.t("cancelled"))
            return

        targets = [t.strip() for t in re.split(r"[,;\s]+", raw) if t.strip()]
        for t in targets:
            if t.isdigit():
                idx = int(t) - 1
                if 0 <= idx < len(mod_names):
                    t = mod_names[idx]
            self.cmd_info(t)
        pause_prompt()

    def _interactive_toggle_mods(self):
        """Interactive enable/disable mod selector with space-separated multi-selection."""
        installed = self.mod_list_mgr.scan_installed_mods()
        if not installed:
            print(f"\n{Colors.YELLOW}{i18n.t('no_mods_found', path=self.mods_dir)}{Colors.RESET}")
            pause_prompt()
            return

        mod_names = sorted(installed.keys())
        print(f"\n{Colors.BOLD}Installed mods:{Colors.RESET}")
        for idx, name in enumerate(mod_names, start=1):
            mod = installed[name][-1]
            if mod.enabled:
                st = f"{Colors.GREEN}[{i18n.t('status_enabled')}]{Colors.RESET}"
            else:
                st = f"{Colors.DIM}[{i18n.t('status_disabled')}]{Colors.RESET}"
            print(f"  {Colors.CYAN}{idx:>2}){Colors.RESET} {st:<21} {Colors.BOLD}{name:<32}{Colors.RESET} v{mod.version}")
        print()

        raw_select = input(f"{Colors.BOLD}{i18n.t('prompt_toggle_select')}{Colors.RESET}").strip()
        selected_indices = parse_multi_selection(raw_select, mod_names)
        if selected_indices is None or not selected_indices:
            print(i18n.t("cancelled"))
            return

        selected_names = [mod_names[i] for i in selected_indices]
        print(f"\nSelected ({len(selected_names)}): {' '.join(selected_names)}")

        action_choice = input(f"{Colors.BOLD}{i18n.t('prompt_toggle_action')}{Colors.RESET}").strip().lower()
        if action_choice in ("q", "cancel", "c"):
            print(i18n.t("cancelled"))
            return

        if action_choice in ("e", "enable", "1"):
            self.cmd_enable_disable(selected_names, enable=True)
        elif action_choice in ("d", "disable", "0"):
            self.cmd_enable_disable(selected_names, enable=False)
        else:  # Toggle
            for name in selected_names:
                curr_enabled = installed[name][-1].enabled
                self.mod_list_mgr.set_mod_state(name, not curr_enabled)
                state_str = i18n.t("status_disabled") if curr_enabled else i18n.t("status_enabled")
                print(i18n.t("mod_state_changed", name=name, state=state_str))

        print(f"\n{Colors.GREEN}{i18n.t('mods_toggled_count', count=len(selected_names))}{Colors.RESET}")
        pause_prompt()

    def _interactive_remove_mods(self):
        """Interactive mod remover with space-separated multi-selection and confirmation."""
        installed = self.mod_list_mgr.scan_installed_mods()
        if not installed:
            print(f"\n{Colors.YELLOW}{i18n.t('no_mods_found', path=self.mods_dir)}{Colors.RESET}")
            pause_prompt()
            return

        mod_names = sorted(installed.keys())
        print(f"\n{Colors.BOLD}Installed mods:{Colors.RESET}")
        for idx, name in enumerate(mod_names, start=1):
            mod = installed[name][-1]
            try:
                size_str = format_bytes(mod.file_path.stat().st_size) if mod.file_path.exists() else "?"
            except Exception:
                size_str = "?"
            print(f"  {Colors.CYAN}{idx:>2}){Colors.RESET} {Colors.BOLD}{name:<32}{Colors.RESET} v{mod.version:<10} ({size_str})")
        print()

        raw_select = input(f"{Colors.BOLD}{i18n.t('prompt_remove_select')}{Colors.RESET}").strip()
        selected_indices = parse_multi_selection(raw_select, mod_names)
        if selected_indices is None or not selected_indices:
            print(i18n.t("cancelled"))
            return

        selected_names = [mod_names[i] for i in selected_indices]
        print(f"\n{Colors.YELLOW}Selected to remove ({len(selected_names)}):{Colors.RESET} {' '.join(selected_names)}")
        
        confirm = input(f"{Colors.BOLD}{i18n.t('prompt_confirm_remove', count=len(selected_names))}{Colors.RESET}").strip().lower()
        if confirm not in ("y", "yes", "д", "да"):
            print(i18n.t("cancelled"))
            return

        self.cmd_remove(selected_names)
        print(f"\n{Colors.GREEN}{i18n.t('mods_removed_count', count=len(selected_names))}{Colors.RESET}")
        pause_prompt()

    def _interactive_optional_mods(self):
        """Scan installed mods for missing optional dependencies and prompt user to download them."""
        installed = self.mod_list_mgr.scan_installed_mods()
        if not installed:
            print(f"\n{Colors.YELLOW}{i18n.t('no_mods_found', path=self.mods_dir)}{Colors.RESET}")
            pause_prompt()
            return

        print(f"\n[*] {i18n.t('scanning_optional')}")
        optional_map: Dict[str, List[str]] = {}

        for mod_name, mod_list in installed.items():
            if mod_name.lower() in ("base", "core", "quality", "space-age", "elevated-rails", "recycler"):
                continue

            local_mod = mod_list[-1]
            deps_list = local_mod.get_dependencies()

            for dep in deps_list:
                if dep.dep_type == DependencyType.OPTIONAL:
                    if dep.name not in installed and not dep.is_virtual:
                        if dep.name not in optional_map:
                            optional_map[dep.name] = []
                        if mod_name not in optional_map[dep.name]:
                            optional_map[dep.name].append(mod_name)

        if not optional_map:
            print(f"\n{Colors.GREEN}{i18n.t('no_optional_found')}{Colors.RESET}\n")
            pause_prompt()
            return

        sorted_opt_names = sorted(optional_map.keys())
        print(f"\n{Colors.BOLD}{i18n.t('optional_header')}{Colors.RESET}\n")
        print(f"{'#':<3} {i18n.t('name_col'):<35} {i18n.t('suggested_by_col')}")
        print("─" * 70)
        for idx, name in enumerate(sorted_opt_names, start=1):
            parents = ", ".join(optional_map[name])
            print(f"{idx:<3} {Colors.BOLD}{name:<35}{Colors.RESET} {Colors.DIM}{parents}{Colors.RESET}")
        print("─" * 70)

        raw_select = input(f"\n{Colors.BOLD}{i18n.t('prompt_optional_select')}{Colors.RESET}").strip()
        selected_indices = parse_multi_selection(raw_select, sorted_opt_names)
        if selected_indices is None or not selected_indices:
            print(i18n.t("cancelled"))
            return

        selected_names = [sorted_opt_names[i] for i in selected_indices]
        self.cmd_install(selected_names, include_optional=False)
        pause_prompt()

    def _interactive_author_mods(self, initial_query: Optional[str] = None):
        """Search and download mods by author/creator interactively across all pages."""
        if initial_query:
            raw_author = initial_query
        else:
            raw_author = input(f"\n{Colors.BOLD}{i18n.t('prompt_author_input')}{Colors.RESET}").strip()

        if not raw_author or raw_author.lower() in ("q", "quit", "cancel", "c", "отмена"):
            print(i18n.t("cancelled"))
            return

        print(f"\n[*] {i18n.t('fetching_author_mods', author=raw_author)}")
        author_clean, author_mods = fetch_author_mods(raw_author)

        if not author_mods:
            print(f"\n{Colors.YELLOW}{i18n.t('author_not_found', author=author_clean or raw_author)}{Colors.RESET}\n")
            pause_prompt()
            return

        installed = self.mod_list_mgr.scan_installed_mods()

        active_cnt = sum(1 for m in author_mods if not m.is_deprecated)
        depr_cnt = sum(1 for m in author_mods if m.is_deprecated)
        count_summary = f"{len(author_mods)} total: {active_cnt} active, {depr_cnt} deprecated" if depr_cnt > 0 else f"{len(author_mods)} found"

        print(f"\n{Colors.BOLD}Mods by author '{author_clean}' ({count_summary}):{Colors.RESET}\n")
        print(f"{'#':<3} {i18n.t('status_col'):<14} {'Factorio':<12} {i18n.t('name_col'):<32} {i18n.t('title_col')}")
        print("─" * 95)

        mod_names = []
        for idx, m in enumerate(author_mods, start=1):
            mod_names.append(m.name)
            if m.name in installed:
                status_str = f"{Colors.GREEN}[{i18n.t('status_installed')}]{Colors.RESET}"
            elif m.is_deprecated:
                status_str = f"{Colors.YELLOW}[Deprecated]{Colors.RESET}"
            else:
                status_str = f"{Colors.DIM} {i18n.t('status_new')}{Colors.RESET}"

            f_ver_str = f"{Colors.GREEN}{m.factorio_versions}{Colors.RESET}" if ("2.0" in m.factorio_versions or "2.1" in m.factorio_versions) else f"{Colors.DIM}{m.factorio_versions}{Colors.RESET}"

            print(f"{idx:<3} {status_str:<23} {f_ver_str:<21} {Colors.BOLD}{m.name:<32}{Colors.RESET} {m.title}")

        print("─" * 95)

        raw_select = input(f"\n{Colors.BOLD}{i18n.t('prompt_author_select')}{Colors.RESET}").strip()
        selected_indices = parse_multi_selection(raw_select, mod_names)
        if selected_indices is None or not selected_indices:
            print(i18n.t("cancelled"))
            return

        selected_targets = [mod_names[i] for i in selected_indices]
        self.cmd_install(selected_targets, include_optional=False)
        pause_prompt()

    def _interactive_search_mods(self, initial_query: Optional[str] = None):
        """Interactive keyword search with scope selection, rich preview and multi-select downloader."""
        if initial_query and initial_query.strip():
            raw_query = initial_query.strip()
        else:
            raw_query = input(f"\n{Colors.BOLD}{i18n.t('prompt_search_query')}{Colors.RESET}").strip()

        if not raw_query or raw_query.lower() in ("q", "quit", "cancel", "c", "отмена"):
            print(i18n.t("cancelled"))
            return

        # Scope selection
        print(f"\n{Colors.BOLD}{i18n.t('prompt_search_scope')}{Colors.RESET}", end="")
        raw_scope = input().strip()
        if raw_scope.lower() in ("q", "quit", "cancel", "c", "отмена"):
            print(i18n.t("cancelled"))
            return

        scope = raw_scope if raw_scope in ("1", "2", "3") else "2"
        installed = self.mod_list_mgr.scan_installed_mods()

        if scope == "3":
            # Search in local installed mods (offline)
            print(f"\n[*] {i18n.t('searching_local', query=raw_query)}")
            results = []
            q_lower = raw_query.lower()
            for name, mod_list in installed.items():
                if name.lower() in ("base", "quality", "space-age", "elevated-rails", "recycler"):
                    continue
                latest = mod_list[-1]
                info = latest.get_info_json()
                title = info.get("title", name)
                desc = info.get("description", "")
                author = info.get("author", "Unknown")
                factorio_ver = info.get("factorio_version", "2.1")
                if q_lower in name.lower() or q_lower in title.lower() or q_lower in desc.lower() or q_lower in author.lower():
                    results.append(SearchModItem(
                        name=name,
                        title=title,
                        owner=author,
                        summary=desc,
                        factorio_versions=factorio_ver,
                        downloads_count=0,
                        is_deprecated=False,
                    ))
        else:
            # Search on Factorio Portal (online)
            only_v2 = (scope == "2")
            print(f"\n[*] {i18n.t('searching_portal', query=raw_query)}")
            results = search_portal_mods(raw_query, only_v2=only_v2, max_pages=5)

        if not results:
            print(f"\n{Colors.YELLOW}{i18n.t('search_no_results', query=raw_query)}{Colors.RESET}\n")
            pause_prompt()
            return

        print(f"\n{Colors.BOLD}{i18n.t('search_results_header', query=raw_query, count=len(results))}{Colors.RESET}\n")
        print(f"{'#':<3} {i18n.t('status_col'):<14} {'Factorio':<12} {i18n.t('name_col'):<32} {i18n.t('author_col'):<16} {i18n.t('title_col')}")
        print("─" * 105)

        mod_names = []
        for idx, m in enumerate(results, start=1):
            mod_names.append(m.name)
            if m.name in installed:
                status_str = f"{Colors.GREEN}[{i18n.t('status_installed')}]{Colors.RESET}"
            elif m.is_deprecated:
                status_str = f"{Colors.YELLOW}[Deprecated]{Colors.RESET}"
            else:
                status_str = f"{Colors.DIM} {i18n.t('status_new')}{Colors.RESET}"

            f_ver_str = f"{Colors.GREEN}{m.factorio_versions}{Colors.RESET}" if ("2.0" in m.factorio_versions or "2.1" in m.factorio_versions) else f"{Colors.DIM}{m.factorio_versions}{Colors.RESET}"
            author_trunc = m.owner[:15] if m.owner else ""
            print(f"{idx:<3} {status_str:<23} {f_ver_str:<21} {Colors.BOLD}{m.name:<32}{Colors.RESET} {author_trunc:<16} {m.title}")
            if m.summary:
                clean_desc = re.sub(r"\s+", " ", m.summary).strip()
                if len(clean_desc) > 85:
                    clean_desc = clean_desc[:82] + "..."
                print(f"    {Colors.DIM}-> {clean_desc}{Colors.RESET}")

        print("─" * 105)

        raw_select = input(f"\n{Colors.BOLD}{i18n.t('prompt_search_select')}{Colors.RESET}").strip()
        selected_indices = parse_multi_selection(raw_select, mod_names)
        if selected_indices is None or not selected_indices:
            print(i18n.t("cancelled"))
            return

        selected_targets = [mod_names[i] for i in selected_indices]
        self.cmd_install(selected_targets, include_optional=False)
        pause_prompt()

    def cmd_search(self, query_parts: List[str], only_v2: bool = False, local: bool = False):
        """Search mods on Factorio Mod Portal or locally by keyword/description."""
        query = " ".join(query_parts).strip()
        if not query:
            self._interactive_search_mods()
            return

        installed = self.mod_list_mgr.scan_installed_mods()

        if local:
            print(f"\n[*] {i18n.t('searching_local', query=query)}")
            results = []
            q_lower = query.lower()
            for name, mod_list in installed.items():
                if name.lower() in ("base", "quality", "space-age", "elevated-rails", "recycler"):
                    continue
                latest = mod_list[-1]
                info = latest.get_info_json()
                title = info.get("title", name)
                desc = info.get("description", "")
                author = info.get("author", "Unknown")
                factorio_ver = info.get("factorio_version", "2.1")
                if q_lower in name.lower() or q_lower in title.lower() or q_lower in desc.lower() or q_lower in author.lower():
                    results.append(SearchModItem(
                        name=name,
                        title=title,
                        owner=author,
                        summary=desc,
                        factorio_versions=factorio_ver,
                        downloads_count=0,
                        is_deprecated=False,
                    ))
        else:
            print(f"\n[*] {i18n.t('searching_portal', query=query)}")
            results = search_portal_mods(query, only_v2=only_v2, max_pages=5)

        if not results:
            print(f"\n{Colors.YELLOW}{i18n.t('search_no_results', query=query)}{Colors.RESET}\n")
            return

        print(f"\n{Colors.BOLD}{i18n.t('search_results_header', query=query, count=len(results))}{Colors.RESET}\n")
        print(f"{'#':<3} {i18n.t('status_col'):<14} {'Factorio':<12} {i18n.t('name_col'):<32} {i18n.t('author_col'):<16} {i18n.t('title_col')}")
        print("─" * 105)

        mod_names = []
        for idx, m in enumerate(results, start=1):
            mod_names.append(m.name)
            if m.name in installed:
                status_str = f"{Colors.GREEN}[{i18n.t('status_installed')}]{Colors.RESET}"
            elif m.is_deprecated:
                status_str = f"{Colors.YELLOW}[Deprecated]{Colors.RESET}"
            else:
                status_str = f"{Colors.DIM} {i18n.t('status_new')}{Colors.RESET}"

            f_ver_str = f"{Colors.GREEN}{m.factorio_versions}{Colors.RESET}" if ("2.0" in m.factorio_versions or "2.1" in m.factorio_versions) else f"{Colors.DIM}{m.factorio_versions}{Colors.RESET}"
            author_trunc = m.owner[:15] if m.owner else ""
            print(f"{idx:<3} {status_str:<23} {f_ver_str:<21} {Colors.BOLD}{m.name:<32}{Colors.RESET} {author_trunc:<16} {m.title}")
            if m.summary:
                clean_desc = re.sub(r"\s+", " ", m.summary).strip()
                if len(clean_desc) > 85:
                    clean_desc = clean_desc[:82] + "..."
                print(f"    {Colors.DIM}-> {clean_desc}{Colors.RESET}")

        print("─" * 105)

        raw_select = input(f"\n{Colors.BOLD}{i18n.t('prompt_search_select')}{Colors.RESET}").strip()
        selected_indices = parse_multi_selection(raw_select, mod_names)
        if selected_indices is None or not selected_indices:
            print(i18n.t("cancelled"))
            return

        selected_targets = [mod_names[i] for i in selected_indices]
        self.cmd_install(selected_targets, include_optional=False)

    def interactive_menu(self):
        """Interactive terminal menu."""
        while True:
            print_banner()
            self.print_env_info()

            lang_label = "Русский" if i18n.lang == "en" else "English"

            print(f"{Colors.BOLD}{i18n.t('menu_title')}{Colors.RESET}")
            print(f"  {Colors.CYAN}1){Colors.RESET} {i18n.t('menu_install')}")
            print(f"  {Colors.CYAN}2){Colors.RESET} {i18n.t('menu_switch')}")
            print(f"  {Colors.CYAN}3){Colors.RESET} {i18n.t('menu_save_profile')}")
            print(f"  {Colors.CYAN}4){Colors.RESET} {i18n.t('menu_check')}")
            print(f"  {Colors.CYAN}5){Colors.RESET} {i18n.t('menu_update')}")
            print(f"  {Colors.CYAN}6){Colors.RESET} {i18n.t('menu_list')}")
            print(f"  {Colors.CYAN}7){Colors.RESET} {i18n.t('menu_info')}")
            print(f"  {Colors.CYAN}8){Colors.RESET} {i18n.t('menu_toggle')}")
            print(f"  {Colors.CYAN}9){Colors.RESET} {i18n.t('menu_remove')}")
            print(f"  {Colors.CYAN}10){Colors.RESET} {i18n.t('menu_export')}")
            print(f"  {Colors.CYAN}11){Colors.RESET} {i18n.t('menu_import')}")
            print(f"  {Colors.CYAN}12){Colors.RESET} {i18n.t('menu_optional')}")
            print(f"  {Colors.CYAN}13){Colors.RESET} {i18n.t('menu_author')}")
            print(f"  {Colors.CYAN}14){Colors.RESET} {i18n.t('menu_search')}")
            print(f"  {Colors.YELLOW}L){Colors.RESET} {i18n.t('menu_lang')} -> {lang_label}")
            print(f"  {Colors.CYAN}q){Colors.RESET} {i18n.t('menu_exit')}")

            try:
                choice = input(f"\n{Colors.BOLD}{i18n.t('prompt_choice')}{Colors.RESET}").strip()
            except (KeyboardInterrupt, EOFError):
                print(f"\n{i18n.t('goodbye')}")
                break

            choice_lower = choice.lower()

            if choice_lower in ("q", "quit", "exit"):
                print(i18n.t("goodbye"))
                break
            elif choice_lower in ("l", "lang", "language"):
                new_l = i18n.toggle_lang()
                print(f"{Colors.GREEN}{i18n.t('lang_changed')}{Colors.RESET}")
            elif choice == "1":
                try:
                    raw = read_pasted_input(f"\n{Colors.BOLD}{i18n.t('prompt_mod_input')}{Colors.RESET}").strip()
                    if raw and raw.lower() not in ("q", "quit", "cancel", "c", "отмена"):
                        targets = [t.strip() for t in re.split(r"[\r\n\t,;\s]+", raw) if t.strip()]
                        if targets:
                            self.cmd_install(targets, include_optional=False)
                            pause_prompt()
                        else:
                            print(i18n.t("cancelled"))
                    else:
                        print(i18n.t("cancelled"))
                except (KeyboardInterrupt, EOFError):
                    print()
            elif choice == "2":
                profs = self.cmd_profile_list()
                if profs:
                    pname = input(f"\n{Colors.BOLD}{i18n.t('prompt_profile_name', max=len(profs))}{Colors.RESET}").strip()
                    if pname and pname.lower() not in ("q", "cancel", "c"):
                        self.cmd_profile_switch(pname)
                        pause_prompt()
                    else:
                        print(i18n.t("cancelled"))
                else:
                    pause_prompt()
            elif choice == "3":
                pname = input(f"\n{Colors.BOLD}{i18n.t('prompt_new_profile_name')}{Colors.RESET}").strip()
                if pname and pname.lower() not in ("q", "cancel", "c"):
                    self.cmd_profile_save(pname)
                    pause_prompt()
                else:
                    print(i18n.t("cancelled"))
            elif choice == "4":
                updates = self.cmd_check_updates(apply=False)
                if updates:
                    apply_ans = input(f"\n{Colors.BOLD}{i18n.t('prompt_apply_updates', count=len(updates))}{Colors.RESET}").strip().lower()
                    if apply_ans in ("", "y", "yes", "д", "да"):
                        mod_names = [u[0] for u in updates]
                        self.cmd_install(mod_names, yes=True)
                pause_prompt()
            elif choice == "5":
                self.cmd_check_updates(apply=True, yes=False)
                pause_prompt()
            elif choice == "6":
                self.cmd_list()
                pause_prompt()
            elif choice == "7":
                self._interactive_mod_info()
            elif choice == "8":
                self._interactive_toggle_mods()
            elif choice == "9":
                self._interactive_remove_mods()
            elif choice == "10":
                try:
                    fname = input(f"\n{Colors.BOLD}{i18n.t('prompt_export_file')}{Colors.RESET}").strip()
                    if fname.lower() in ("q", "cancel", "c"):
                        print(i18n.t("cancelled"))
                    else:
                        self.cmd_export(fname or "modpack.json")
                        pause_prompt()
                except (KeyboardInterrupt, EOFError):
                    print()
            elif choice == "11":
                try:
                    fname = input(f"\n{Colors.BOLD}{i18n.t('prompt_import_file')}{Colors.RESET}").strip()
                    if not fname or fname.lower() in ("q", "cancel", "c"):
                        print(i18n.t("cancelled"))
                    else:
                        self.cmd_import(fname, include_optional=False)
                        pause_prompt()
                except (KeyboardInterrupt, EOFError):
                    print()
            elif choice == "12":
                self._interactive_optional_mods()
            elif choice == "13":
                self._interactive_author_mods()
            elif choice == "14":
                self._interactive_search_mods()
            else:
                print(f"{Colors.RED}{i18n.t('invalid_choice')}{Colors.RESET}")

            print("\n" + "═" * 60 + "\n")
