"""API client for re146.dev mirror and Factorio Mod Portal."""

from __future__ import annotations
import html
import json
import re
import urllib.parse
import urllib.request
import urllib.error
from typing import Any, Dict, List, Optional, Tuple

from .i18n import i18n
from .version import Dependency, FactorioVersion

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
RE146_BASE_STORAGE = "https://mods-storage.re146.dev/"
RE146_MODINFO_URL = "https://re146.dev/factorio/mods/modinfo?id="
FACTORIO_PORTAL_API = "https://mods.factorio.com/api/mods/"


def parse_mod_input(input_str: str) -> Tuple[str, Optional[str], Optional[str]]:
    """
    Parse a user input (URL or name or versioned string) into (mod_name, version, op).
    """
    raw = input_str.strip()
    if not raw:
        return "", None, None

    # Check for re146 hash fragment
    if "re146.dev/factorio/mods" in raw:
        parts = raw.split("#")
        if len(parts) > 1:
            frag = parts[1]
            if len(parts) > 2:
                frag_ver = parts[2]
            else:
                frag_ver = None

            if "mods.factorio.com" in frag:
                raw = frag
            else:
                mod_name = frag.strip("/")
                return mod_name, frag_ver, "==" if frag_ver else None

    # Check for official portal URL
    if "mods.factorio.com" in raw:
        m = re.search(r"mods\.factorio\.com/mod(?:s/[^/]+)?/([^/?#]+)", raw, re.IGNORECASE)
        if m:
            mod_name = m.group(1)
            m_ver = re.search(r"/downloads#?(\d+(?:\.\d+)*)?", raw)
            ver = m_ver.group(1) if m_ver and m_ver.group(1) else None
            return mod_name, ver, "==" if ver else None

    # Check for version specifier: name@version, name==version, name>=version, etc.
    m_spec = re.match(r"^([%\w\.-]+)\s*(@|==|=|>=|<=|>|<)\s*(\d+(?:\.\d+)*)$", raw)
    if m_spec:
        name, op, ver = m_spec.groups()
        op_norm = "==" if op in ("@", "=") else op
        return name, ver, op_norm

    return raw, None, None


def fetch_author_mods(author_or_url: str) -> Tuple[str, List[Tuple[str, str]]]:
    """
    Fetch all mods created by an author from Factorio Mod Portal.
    Returns (cleaned_author_username, list_of_tuples[(mod_name, mod_title)]).
    """
    raw = author_or_url.strip()
    if not raw:
        return "", []

    # Extract username from URL if given
    if "mods.factorio.com/user/" in raw:
        author_name = raw.split("mods.factorio.com/user/")[-1].split("/")[0].split("?")[0].strip()
    elif "factorio.com/user/" in raw:
        author_name = raw.split("factorio.com/user/")[-1].split("/")[0].split("?")[0].strip()
    else:
        author_name = raw

    mods_dict: Dict[str, str] = {}
    page = 1
    while True:
        url = f"https://mods.factorio.com/user/{urllib.parse.quote(author_name)}?page={page}"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                html_text = resp.read().decode("utf-8")
        except Exception:
            break

        matches = re.findall(r'<a href="/mod/([^"/?#]+)"[^>]*>(.*?)</a>', html_text, re.DOTALL)
        found_on_page = 0
        for mod_name, raw_title in matches:
            clean_title = html.unescape(re.sub(r"<[^<]+?>", "", raw_title)).strip()
            if mod_name not in mods_dict:
                mods_dict[mod_name] = clean_title if clean_title != mod_name else ""
                found_on_page += 1
            else:
                if clean_title and clean_title != mod_name and not mods_dict[mod_name]:
                    mods_dict[mod_name] = clean_title

        if found_on_page == 0:
            break

        page += 1
        if page > 25:
            break

    result = [(name, title if title else name) for name, title in mods_dict.items()]
    return author_name, result


class ReleaseInfo:
    def __init__(
        self,
        version: FactorioVersion,
        factorio_version: str,
        dependencies: List[Dependency],
        sha1: Optional[str],
        file_name: str,
        released_at: str,
        download_url: str,
    ):
        self.version = version
        self.factorio_version = factorio_version
        self.dependencies = dependencies
        self.sha1 = sha1
        self.file_name = file_name
        self.released_at = released_at
        self.download_url = download_url

    def __repr__(self) -> str:
        return f"<Release {self.version} (Factorio {self.factorio_version})>"


class ModInfo:
    def __init__(
        self,
        name: str,
        title: str,
        owner: str,
        summary: str,
        category: str,
        downloads_count: int,
        releases: List[ReleaseInfo],
        raw_data: Dict[str, Any],
    ):
        self.name = name
        self.title = title
        self.owner = owner
        self.summary = summary
        self.category = category
        self.downloads_count = downloads_count
        self.releases = releases
        self.raw_data = raw_data

    def get_latest_release(self, target_factorio_branch: Optional[str] = None) -> Optional[ReleaseInfo]:
        """Get the latest release, optionally filtered by compatible Factorio branch (e.g. '2.1', '2.0', '1.1')."""
        if not self.releases:
            return None

        if not target_factorio_branch:
            return self.releases[-1]

        target_v = FactorioVersion(target_factorio_branch)

        # 1. Exact branch match (e.g. 2.1 -> 2.1)
        for rel in reversed(self.releases):
            if rel.factorio_version:
                rel_f_v = FactorioVersion(rel.factorio_version)
                if rel_f_v.is_compatible_major_minor(str(target_v)):
                    return rel

            for dep in rel.dependencies:
                if dep.name == "base" and dep.version:
                    if dep.version.is_compatible_major_minor(str(target_v)):
                        return rel

        # 2. Compatible version within the same major version family
        for rel in reversed(self.releases):
            if rel.factorio_version:
                rel_f_v = FactorioVersion(rel.factorio_version)
                if len(rel_f_v.parts) >= 1 and len(target_v.parts) >= 1 and rel_f_v.parts[0] == target_v.parts[0]:
                    if rel_f_v <= target_v:
                        base_dep = next((d for d in rel.dependencies if d.name == "base"), None)
                        if not base_dep or base_dep.satisfies(target_v):
                            return rel

        return self.releases[-1]

    def find_release(
        self,
        version_req: Optional[str] = None,
        op: Optional[str] = None,
        target_factorio_branch: Optional[str] = None,
    ) -> Optional[ReleaseInfo]:
        """Find the best matching release for version constraint."""
        if not self.releases:
            return None

        if not version_req:
            return self.get_latest_release(target_factorio_branch)

        req_v = FactorioVersion(version_req)
        op = op or "=="

        candidates: List[ReleaseInfo] = []
        for rel in self.releases:
            matches_ver = False
            if op in ("==", "=") and rel.version == req_v:
                matches_ver = True
            elif op == ">=" and rel.version >= req_v:
                matches_ver = True
            elif op == "<=" and rel.version <= req_v:
                matches_ver = True
            elif op == ">" and rel.version > req_v:
                matches_ver = True
            elif op == "<" and rel.version < req_v:
                matches_ver = True

            if matches_ver:
                candidates.append(rel)

        if not candidates:
            return None

        if target_factorio_branch:
            target_v = FactorioVersion(target_factorio_branch)
            branch_candidates = [
                r for r in candidates
                if FactorioVersion(r.factorio_version).is_compatible_major_minor(target_factorio_branch)
            ]
            if branch_candidates:
                return branch_candidates[-1]

            major_candidates = [
                r for r in candidates
                if len(FactorioVersion(r.factorio_version).parts) >= 1
                and FactorioVersion(r.factorio_version).parts[0] == target_v.parts[0]
                and FactorioVersion(r.factorio_version) <= target_v
            ]
            if major_candidates:
                return major_candidates[-1]

        return candidates[-1]


class ModPortalClient:
    """Client for querying mod metadata and obtaining mirror download links."""

    def __init__(self, cache_enabled: bool = True):
        self.cache_enabled = cache_enabled
        self._cache: Dict[str, ModInfo] = {}

    def fetch_mod_info(self, mod_name: str) -> ModInfo:
        """Fetch metadata for a mod by ID / name, checking re146 then official portal."""
        cleaned_name = mod_name.strip()
        if not cleaned_name:
            raise ValueError("Mod name cannot be empty")

        if self.cache_enabled and cleaned_name in self._cache:
            return self._cache[cleaned_name]

        data = None
        last_error = None

        # 1. Try re146.dev modinfo endpoint
        re146_url = f"{RE146_MODINFO_URL}{urllib.parse.quote(cleaned_name)}"
        try:
            req = urllib.request.Request(re146_url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=12) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except Exception as e:
            last_error = e

        # 2. Fallback to official mods.factorio.com API
        if not data or "name" not in data:
            official_url = f"{FACTORIO_PORTAL_API}{urllib.parse.quote(cleaned_name)}/full"
            try:
                req = urllib.request.Request(official_url, headers={"User-Agent": USER_AGENT})
                with urllib.request.urlopen(req, timeout=12) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
            except urllib.error.HTTPError as he:
                if he.code == 404:
                    raise ValueError(i18n.t("api_mod_not_found", name=cleaned_name))
                raise RuntimeError(i18n.t("api_req_error", err=he))
            except Exception as e:
                raise RuntimeError(i18n.t("api_fetch_failed", name=cleaned_name, err=e or last_error))

        if not data or "name" not in data:
            raise ValueError(i18n.t("api_data_corrupted", name=cleaned_name))

        releases: List[ReleaseInfo] = []
        for rel_raw in data.get("releases", []):
            ver_str = rel_raw.get("version", "0.0.1")
            info_json = rel_raw.get("info_json", {})
            f_ver = info_json.get("factorio_version", "2.1")
            raw_deps = info_json.get("dependencies", [])
            deps: List[Dependency] = []
            for d in raw_deps:
                parsed_dep = Dependency.parse(d)
                if parsed_dep:
                    deps.append(parsed_dep)

            download_url = f"{RE146_BASE_STORAGE}{cleaned_name}/{ver_str}.zip"

            rel = ReleaseInfo(
                version=FactorioVersion(ver_str),
                factorio_version=f_ver,
                dependencies=deps,
                sha1=rel_raw.get("sha1"),
                file_name=rel_raw.get("file_name", f"{cleaned_name}_{ver_str}.zip"),
                released_at=rel_raw.get("released_at", ""),
                download_url=download_url,
            )
            releases.append(rel)

        releases.sort(key=lambda r: r.version)

        mod_info = ModInfo(
            name=data.get("name", cleaned_name),
            title=data.get("title", cleaned_name),
            owner=data.get("owner", "Unknown"),
            summary=data.get("summary", ""),
            category=data.get("category", ""),
            downloads_count=data.get("downloads_count", 0),
            releases=releases,
            raw_data=data,
        )

        if self.cache_enabled:
            self._cache[cleaned_name] = mod_info

        return mod_info
