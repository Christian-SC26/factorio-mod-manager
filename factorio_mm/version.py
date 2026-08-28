"""Factorio version and dependency parsing utilities."""

from __future__ import annotations
import re
from typing import Optional, Tuple, Union


class FactorioVersion:
    """Represents a Factorio version (e.g. '1.1.80', '2.0.28', '0.17.2')."""

    def __init__(self, version_str: Union[str, Tuple[int, ...], FactorioVersion]):
        if isinstance(version_str, FactorioVersion):
            self.parts = version_str.parts
            self.raw = version_str.raw
            return

        if isinstance(version_str, tuple):
            self.parts = version_str
            self.raw = ".".join(str(x) for x in version_str)
            return

        self.raw = str(version_str).strip()
        # Clean up any build metadata or suffixes if present (e.g., '1.1.80-1')
        clean = re.split(r"[-+]", self.raw)[0]
        parts = []
        for p in clean.split("."):
            try:
                parts.append(int(p))
            except ValueError:
                parts.append(0)
        self.parts = tuple(parts) if parts else (0, 0, 0)

    def __str__(self) -> str:
        return self.raw

    def __repr__(self) -> str:
        return f"FactorioVersion('{self.raw}')"

    def _pad(self, other: FactorioVersion) -> Tuple[Tuple[int, ...], Tuple[int, ...]]:
        max_len = max(len(self.parts), len(other.parts))
        p1 = self.parts + (0,) * (max_len - len(self.parts))
        p2 = other.parts + (0,) * (max_len - len(other.parts))
        return p1, p2

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, (FactorioVersion, str)):
            return False
        other_ver = other if isinstance(other, FactorioVersion) else FactorioVersion(other)
        p1, p2 = self._pad(other_ver)
        return p1 == p2

    def __lt__(self, other: Union[FactorioVersion, str]) -> bool:
        other_ver = other if isinstance(other, FactorioVersion) else FactorioVersion(other)
        p1, p2 = self._pad(other_ver)
        return p1 < p2

    def __le__(self, other: Union[FactorioVersion, str]) -> bool:
        other_ver = other if isinstance(other, FactorioVersion) else FactorioVersion(other)
        p1, p2 = self._pad(other_ver)
        return p1 <= p2

    def __gt__(self, other: Union[FactorioVersion, str]) -> bool:
        other_ver = other if isinstance(other, FactorioVersion) else FactorioVersion(other)
        p1, p2 = self._pad(other_ver)
        return p1 > p2

    def __ge__(self, other: Union[FactorioVersion, str]) -> bool:
        other_ver = other if isinstance(other, FactorioVersion) else FactorioVersion(other)
        p1, p2 = self._pad(other_ver)
        return p1 >= p2

    def __hash__(self) -> int:
        return hash(self.parts)

    def is_compatible_major_minor(self, branch: str) -> bool:
        """Check if this version belongs to branch like '1.1' or '2.0'."""
        branch_ver = FactorioVersion(branch)
        if len(branch_ver.parts) == 1:
            return len(self.parts) > 0 and self.parts[0] == branch_ver.parts[0]
        if len(branch_ver.parts) >= 2:
            return (
                len(self.parts) >= 2
                and self.parts[0] == branch_ver.parts[0]
                and self.parts[1] == branch_ver.parts[1]
            )
        return True


# Regex for Factorio dependency string:
# Format: [(! | ? | (?) | ~ | +)] [name] [(< | <= | = | == | >= | >) version]
DEP_REGEX = re.compile(
    r"^(?P<prefix>\?|\(\?\)|!|~|\+)?\s*(?P<name>[%\w\s\.-]+?)(?:\s*(?P<op><=|>=|==|=|<|>)\s*(?P<version>\d+(?:\.\d+)*))?$",
    re.IGNORECASE,
)

VIRTUAL_BUILTINS = {
    "base",
    "core",
    "quality",
    "space-age",
    "elevated-rails",
    "recycler",
}


class DependencyType:
    REQUIRED = "required"          # No prefix: strictly required
    RECOMMENDED = "recommended"    # '+': recommended by author
    OPTIONAL = "optional"          # '?': optional addon
    INCOMPATIBLE = "incompatible"  # '!': incompatible conflict


class Dependency:
    """Represents a single dependency parsed from Factorio mod metadata."""

    def __init__(
        self,
        name: str,
        dep_type: str = DependencyType.REQUIRED,
        op: Optional[str] = None,
        version: Optional[FactorioVersion] = None,
        raw_str: str = "",
    ):
        self.name = name.strip()
        self.dep_type = dep_type
        self.op = "==" if op == "=" else op
        self.version = version
        self.raw_str = raw_str

    @property
    def is_virtual(self) -> bool:
        """Check if dependency is a built-in game component."""
        return self.name.lower() in VIRTUAL_BUILTINS

    @property
    def is_required(self) -> bool:
        """Check if this dependency is strictly required to run."""
        return self.dep_type == DependencyType.REQUIRED

    @property
    def is_conflict(self) -> bool:
        return self.dep_type == DependencyType.INCOMPATIBLE

    @classmethod
    def parse(cls, dep_str: str) -> Optional[Dependency]:
        """
        Parse a Factorio dependency string.
        Ignored / insignificant load-order hints '(?)' and '~' are skipped (return None).
        """
        if not dep_str or not isinstance(dep_str, str):
            return None
        cleaned = dep_str.strip()
        if not cleaned:
            return None

        m = DEP_REGEX.match(cleaned)
        if not m:
            return Dependency(name=cleaned, raw_str=dep_str)

        prefix = (m.group("prefix") or "").strip()
        name = m.group("name").strip()
        op = m.group("op")
        ver_str = m.group("version")

        # Ignore hidden optional '(?)' and load-order '~' hints completely
        if prefix in ("(?)", "( ? )", "~"):
            return None

        dep_type = DependencyType.REQUIRED
        if prefix == "!":
            dep_type = DependencyType.INCOMPATIBLE
        elif prefix == "+":
            dep_type = DependencyType.RECOMMENDED
        elif prefix == "?":
            dep_type = DependencyType.OPTIONAL

        version = FactorioVersion(ver_str) if ver_str else None

        return cls(
            name=name,
            dep_type=dep_type,
            op=op,
            version=version,
            raw_str=dep_str,
        )

    def satisfies(self, target_version: Union[str, FactorioVersion]) -> bool:
        """Check if target_version satisfies this dependency condition."""
        if not self.version or not self.op:
            return True

        ver = target_version if isinstance(target_version, FactorioVersion) else FactorioVersion(target_version)
        req = self.version

        if self.op in ("==", "="):
            return ver == req
        elif self.op == ">=":
            return ver >= req
        elif self.op == "<=":
            return ver <= req
        elif self.op == ">":
            return ver > req
        elif self.op == "<":
            return ver < req
        return True

    def __repr__(self) -> str:
        ver_info = f" {self.op} {self.version}" if self.version and self.op else ""
        return f"<Dependency [{self.dep_type}] {self.name}{ver_info}>"
