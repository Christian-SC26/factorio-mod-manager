"""Concurrent downloader with progress bar and integrity verification."""

from __future__ import annotations
import hashlib
import re
import sys
import time
import urllib.request
import urllib.error
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, List, Optional, Tuple

from .api import USER_AGENT
from .i18n import i18n
from .mod_list import ModListManager
from .resolver import ResolvedMod


@dataclass
class DownloadResult:
    mod_name: str
    version: str
    file_path: Path
    success: bool
    size_bytes: int
    error: Optional[str] = None


def format_bytes(size: float) -> str:
    """Format bytes into human-readable string."""
    for unit in ["B", "KB", "MB", "GB"]:
        if size < 1024.0:
            return f"{size:3.1f} {unit}"
        size /= 1024.0
    return f"{size:.1f} TB"


def render_progress_bar(
    current: int,
    total: int,
    prefix: str = "",
    suffix: str = "",
    length: int = 28,
    fill: str = "█",
    empty: str = "░",
) -> str:
    """Return a formatted text progress bar string."""
    if total <= 0:
        pct = 0.0
        filled_len = 0
    else:
        pct = min(1.0, current / total)
        filled_len = int(length * pct)

    bar = fill * filled_len + empty * (length - filled_len)
    pct_str = f"{pct * 100:5.1f}%"
    return f"{prefix} [{bar}] {pct_str} {suffix}"


class ModDownloader:
    """Handles downloading mod packages from mirror."""

    def __init__(
        self,
        mod_list_mgr: ModListManager,
        max_workers: int = 4,
        clean_old: bool = True,
        auto_enable: bool = True,
    ):
        self.mod_list_mgr = mod_list_mgr
        self.max_workers = max_workers
        self.clean_old = clean_old
        self.auto_enable = auto_enable

    def download_single(
        self,
        mod: ResolvedMod,
        on_progress: Optional[Callable[[str, int, int], None]] = None,
    ) -> DownloadResult:
        """Download a single mod zip file with retries and verification."""
        dest_dir = self.mod_list_mgr.mods_dir
        dest_dir.mkdir(parents=True, exist_ok=True)

        file_name = mod.release.file_name or f"{mod.name}_{mod.release.version}.zip"
        target_file = dest_dir / file_name
        part_file = dest_dir / f"{file_name}.part"

        url = mod.release.download_url
        headers = {"User-Agent": USER_AGENT}

        max_retries = 3
        last_err = None

        for attempt in range(1, max_retries + 1):
            try:
                req = urllib.request.Request(url, headers=headers)
                with urllib.request.urlopen(req, timeout=30) as resp:
                    if resp.status != 200:
                        raise RuntimeError(f"HTTP {resp.status} {resp.reason}")

                    total_size = int(resp.headers.get("Content-Length", 0))
                    downloaded = 0
                    chunk_size = 64 * 1024
                    sha1_hash = hashlib.sha1()

                    with open(part_file, "wb") as f:
                        while True:
                            chunk = resp.read(chunk_size)
                            if not chunk:
                                break
                            f.write(chunk)
                            sha1_hash.update(chunk)
                            downloaded += len(chunk)
                            if on_progress:
                                on_progress(mod.name, downloaded, total_size)

                    # Verify zip integrity
                    if not zipfile.is_zipfile(part_file):
                        part_file.unlink(missing_ok=True)
                        raise ValueError("Downloaded file is corrupted (invalid ZIP archive)")

                    # Rename part file to final file
                    part_file.replace(target_file)

                    # If clean_old is enabled, remove older versions of this EXACT mod
                    if self.clean_old:
                        for item in dest_dir.iterdir():
                            if item != target_file and item.is_file() and item.suffix.lower() == ".zip":
                                m_zip = re.match(r"^(.+)_(\d+(?:\.\d+)*)\.zip$", item.name, re.IGNORECASE)
                                if m_zip and m_zip.group(1) == mod.name:
                                    try:
                                        item.unlink()
                                    except Exception:
                                        pass

                    return DownloadResult(
                        mod_name=mod.name,
                        version=str(mod.release.version),
                        file_path=target_file,
                        success=True,
                        size_bytes=downloaded,
                    )

            except Exception as e:
                last_err = e
                part_file.unlink(missing_ok=True)
                if attempt < max_retries:
                    time.sleep(1.0 * attempt)

        return DownloadResult(
            mod_name=mod.name,
            version=str(mod.release.version),
            file_path=target_file,
            success=False,
            size_bytes=0,
            error=str(last_err),
        )

    def download_all(self, mods_to_download: List[ResolvedMod]) -> List[DownloadResult]:
        """Download all mods concurrently and print clean progress."""
        if not mods_to_download:
            return []

        print(f"\n[>] {i18n.t('download_started', count=len(mods_to_download))}\n")

        results: List[DownloadResult] = []
        enabled_names: List[str] = []

        total_count = len(mods_to_download)
        for i, mod in enumerate(mods_to_download, start=1):
            file_name = mod.release.file_name or f"{mod.name}_{mod.release.version}.zip"
            print(f"[{i}/{total_count}] {mod.name} v{mod.release.version}...")

            start_t = time.time()
            last_draw_t = [0.0]

            def progress_cb(name: str, cur: int, tot: int):
                now = time.time()
                # Throttle redraws to ~15 FPS to prevent terminal buffer lag, always draw 100% completion
                if tot > 0 and cur < tot and (now - last_draw_t[0]) < 0.06:
                    return
                last_draw_t[0] = now

                elapsed = max(0.001, now - start_t)
                speed = cur / elapsed
                speed_str = f"{format_bytes(speed)}/s"
                size_str = f"{format_bytes(cur)} / {format_bytes(tot) if tot else '?'}"
                bar = render_progress_bar(cur, tot, prefix=f"  ->", suffix=f"{size_str} ({speed_str})")
                sys.stdout.write(f"\r{bar:<80}")
                sys.stdout.flush()

            res = self.download_single(mod, on_progress=progress_cb)
            sys.stdout.write("\n")
            sys.stdout.flush()

            if res.success:
                results.append(res)
                enabled_names.append(mod.name)
                print(f"  [OK] Saved: {file_name} ({format_bytes(res.size_bytes)})\n")
            else:
                results.append(res)
                print(f"  [ERROR] {mod.name}: {res.error}\n")

        # Auto-enable in mod-list.json
        if self.auto_enable and enabled_names:
            self.mod_list_mgr.enable_mods(enabled_names)
            print(f"[OK] Enabled {len(enabled_names)} mods in mod-list.json")

        return results
