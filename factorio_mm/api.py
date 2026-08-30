"""API client for re146.dev mirror and Factorio Mod Portal."""

from __future__ import annotations
import html
import json
import re
import urllib.parse
import urllib.request
import urllib.error
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

from .i18n import i18n
from .version import Dependency, FactorioVersion

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
RE146_BASE_STORAGE = "https://mods-storage.re146.dev/"
RE146_MODINFO_URL = "https://re146.dev/factorio/mods/modinfo?id="
FACTORIO_PORTAL_API = "https://mods.factorio.com/api/mods/"


@dataclass
class AuthorModItem:
    name: str
    title: str
    factorio_versions: str
    downloads_count: int
    is_deprecated: bool


@dataclass
class SearchModItem:
    name: str
    title: str
    owner: str
    summary: str
    factorio_versions: str
    downloads_count: int
    is_deprecated: bool


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


def _parse_html_mod_cards(html_text: str) -> List[SearchModItem]:
    """Parse mod cards from Factorio Mod Portal HTML pages."""
    cards: List[SearchModItem] = []
    chunks = html_text.split('class="panel-inset-lighter flex-column p0')
    for chunk in chunks[1:]:
        m_link = re.search(r'href="/mod/([^"/?#]+)', chunk)
        if not m_link:
            continue

        name = m_link.group(1).strip()

        # Title
        m_title = re.search(r'<h2[^>]*>.*?<a[^>]*>(.*?)</a>', chunk, re.DOTALL)
        title = html.unescape(re.sub(r"<[^<]+?>", "", m_title.group(1))).strip() if m_title else name

        # Owner
        m_owner = re.search(r'href="/user/([^"/?#]+)"', chunk)
        owner = m_owner.group(1).strip() if m_owner else "Unknown"

        # Summary
        m_summary = (
            re.search(r'<p\s+class="[^"<>]*result-field[^"<>]*"[^>]*>(.*?)(?:</p>|</div>)', chunk, re.DOTALL)
            or re.search(r'<p[^>]*class="[^"<>]*line-clamp[^"<>]*"[^>]*>(.*?)(?:</p>|</div>)', chunk, re.DOTALL)
            or re.search(r'<div class="mod-card-summary[^"]*"[^>]*>(.*?)</div>', chunk, re.DOTALL)
        )
        summary = html.unescape(re.sub(r"<[^<]+?>", "", m_summary.group(1))).strip() if m_summary else ""

        # Factorio versions
        m_fver = re.search(r'title="Available for these Factorio versions"[^>]*>.*?<i[^>]*></i>\s*([^<\n]+)', chunk, re.DOTALL)
        f_vers = m_fver.group(1).strip() if m_fver else ""

        # Downloads count
        m_dl = re.search(r'title="Downloads[^"]*"[^>]*>.*?<span title="(\d+)"', chunk, re.DOTALL)
        dl_cnt = int(m_dl.group(1)) if m_dl else 0

        # Deprecated
        is_depr = ('class="deprecated"' in chunk) or ('deprecated' in chunk.lower() and "<span" in chunk)

        cards.append(SearchModItem(
            name=name,
            title=title,
            owner=owner,
            summary=summary,
            factorio_versions=f_vers,
            downloads_count=dl_cnt,
            is_deprecated=is_depr,
        ))
    return cards


def fetch_author_mods(author_or_url: str) -> Tuple[str, List[AuthorModItem]]:
    """
    Fetch all mods created by an author from Factorio Mod Portal across all pages.
    Handles path-based pagination (/user/<name>/1, /user/<name>/2, ...).
    Returns (cleaned_author_username, list_of_AuthorModItem).
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

    mods: List[AuthorModItem] = []
    seen_names = set()
    page = 1

    while True:
        url = f"https://mods.factorio.com/user/{urllib.parse.quote(author_name)}/{page}" if page > 1 else f"https://mods.factorio.com/user/{urllib.parse.quote(author_name)}"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                html_text = resp.read().decode("utf-8")
        except Exception:
            break

        cards = _parse_html_mod_cards(html_text)
        found_on_page = 0
        for c in cards:
            if c.name not in seen_names:
                seen_names.add(c.name)
                found_on_page += 1
                mods.append(AuthorModItem(
                    name=c.name,
                    title=c.title,
                    factorio_versions=c.factorio_versions,
                    downloads_count=c.downloads_count,
                    is_deprecated=c.is_deprecated,
                ))

        if found_on_page == 0 or page > 30:
            break
        page += 1

    return author_name, mods


def search_portal_mods(query: str, only_v2: bool = False, max_pages: int = 5) -> List[SearchModItem]:
    """
    Search Factorio Mod Portal by keyword/query across multiple pages.
    Returns list of SearchModItem with name, title, owner, summary, versions, downloads.
    """
    raw = query.strip()
    if not raw:
        return []

    mods: List[SearchModItem] = []
    seen_names = set()

    for page in range(1, max_pages + 1):
        url = f"https://mods.factorio.com/search?query={urllib.parse.quote(raw)}" + (f"&page={page}" if page > 1 else "")
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                html_text = resp.read().decode("utf-8")
        except Exception:
            break

        cards = _parse_html_mod_cards(html_text)
        found_on_page = 0
        for c in cards:
            if c.name not in seen_names:
                seen_names.add(c.name)
                found_on_page += 1
                if only_v2 and c.factorio_versions:
                    if "2.0" not in c.factorio_versions and "2.1" not in c.factorio_versions and "2." not in c.factorio_versions:
                        continue
                mods.append(c)

        if found_on_page == 0:
            break

    return mods


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
