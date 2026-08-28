"""Factorio mod dependency resolution engine."""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple

from .api import ModInfo, ModPortalClient, ReleaseInfo, parse_mod_input
from .mod_list import LocalMod, ModListManager
from .version import Dependency, DependencyType, FactorioVersion


@dataclass
class ResolvedMod:
    name: str
    info: ModInfo
    release: ReleaseInfo
    required_by: Set[str] = field(default_factory=set)
    recommended_by: Set[str] = field(default_factory=set)
    optional_by: Set[str] = field(default_factory=set)
    is_root: bool = False
    is_already_installed: bool = False
    installed_version: Optional[FactorioVersion] = None
    action: str = "DOWNLOAD"  # "DOWNLOAD", "UPDATE", "KEEP", "CONFLICT"
    conflict_reasons: List[str] = field(default_factory=list)


@dataclass
class ResolutionResult:
    mods_to_download: List[ResolvedMod]
    mods_up_to_date: List[ResolvedMod]
    conflicts: List[Tuple[str, str, str]]  # (mod_a, mod_b, reason)
    missing_mods: List[Tuple[str, str]]    # (mod_name, required_by)
    warnings: List[str]
    root_mods: List[str]
    dependency_graph: Dict[str, List[str]]


class DependencyResolver:
    """Recursively resolves mod dependencies and detects conflicts."""

    def __init__(
        self,
        client: ModPortalClient,
        mod_list_mgr: ModListManager,
        target_factorio_branch: Optional[str] = None,
        include_recommended: bool = True,
        include_optional: bool = False,
        force_reinstall: bool = False,
    ):
        self.client = client
        self.mod_list_mgr = mod_list_mgr
        self.target_factorio_branch = target_factorio_branch
        self.include_recommended = include_recommended
        self.include_optional = include_optional
        self.force_reinstall = force_reinstall

        self.installed_mods = self.mod_list_mgr.scan_installed_mods()
        self.resolved: Dict[str, ResolvedMod] = {}
        self.visited: Set[str] = set()
        self.conflicts: List[Tuple[str, str, str]] = []
        self.missing: List[Tuple[str, str]] = []
        self.warnings: List[str] = []
        self.graph: Dict[str, List[str]] = {}

    def resolve(self, mod_inputs: List[str]) -> ResolutionResult:
        """Resolve a list of mod inputs (names, URLs, or versioned specs)."""
        root_names: List[str] = []

        for raw_input in mod_inputs:
            name, ver_req, op = parse_mod_input(raw_input)
            if not name:
                continue

            root_names.append(name)
            self._resolve_mod_recursive(
                mod_name=name,
                version_req=ver_req,
                op=op,
                parent=None,
                dep_type=DependencyType.REQUIRED,
                is_root=True,
            )

        # Check for conflicts between all resolved mods
        self._check_conflicts()

        # Categorize results
        to_download: List[ResolvedMod] = []
        up_to_date: List[ResolvedMod] = []

        for mod in self.resolved.values():
            if mod.action in ("DOWNLOAD", "UPDATE"):
                to_download.append(mod)
            elif mod.action == "KEEP":
                up_to_date.append(mod)

        return ResolutionResult(
            mods_to_download=to_download,
            mods_up_to_date=up_to_date,
            conflicts=self.conflicts,
            missing_mods=self.missing,
            warnings=self.warnings,
            root_mods=root_names,
            dependency_graph=self.graph,
        )

    def _resolve_mod_recursive(
        self,
        mod_name: str,
        version_req: Optional[str] = None,
        op: Optional[str] = None,
        parent: Optional[str] = None,
        dep_type: str = DependencyType.REQUIRED,
        is_root: bool = False,
    ):
        # Ignore virtual base mods
        if mod_name.lower() in ("base", "core", "quality", "space-age", "elevated-rails"):
            return

        # Track graph
        if parent:
            if parent not in self.graph:
                self.graph[parent] = []
            if mod_name not in self.graph[parent]:
                self.graph[parent].append(mod_name)

        # If already resolved, update required_by and check version constraint
        if mod_name in self.resolved:
            existing = self.resolved[mod_name]
            if parent:
                if dep_type == DependencyType.REQUIRED:
                    existing.required_by.add(parent)
                elif dep_type == DependencyType.RECOMMENDED:
                    existing.recommended_by.add(parent)
                elif dep_type in (DependencyType.OPTIONAL, DependencyType.HIDDEN_OPT):
                    existing.optional_by.add(parent)

            if version_req and op:
                # Validate that currently selected release satisfies this additional constraint
                dep_check = Dependency(name=mod_name, op=op, version=FactorioVersion(version_req))
                if not dep_check.satisfies(existing.release.version):
                    # Try to find a release that satisfies both
                    new_rel = existing.info.find_release(
                        version_req=version_req,
                        op=op,
                        target_factorio_branch=self.target_factorio_branch,
                    )
                    if new_rel:
                        existing.release = new_rel
                    else:
                        self.warnings.append(
                            f"Конфликт версий для '{mod_name}': требуется {op} {version_req} (для {parent}), "
                            f"но выбрана версия {existing.release.version}"
                        )
            return

        # Fetch mod info
        try:
            mod_info = self.client.fetch_mod_info(mod_name)
        except Exception as e:
            self.missing.append((mod_name, parent or "пользователь"))
            self.warnings.append(f"Не удалось найти мод '{mod_name}' (запрошен '{parent or 'root'}'): {e}")
            return

        # Pick matching release
        release = mod_info.find_release(
            version_req=version_req,
            op=op,
            target_factorio_branch=self.target_factorio_branch,
        )

        if not release:
            self.missing.append((mod_name, parent or "пользователь"))
            self.warnings.append(
                f"Не найдена подходящая версия для '{mod_name}' "
                f"({op or ''} {version_req or ''}, Factorio: {self.target_factorio_branch or 'любая'})"
            )
            return

        # Check local installation
        is_installed = False
        installed_ver: Optional[FactorioVersion] = None
        action = "DOWNLOAD"

        if mod_name in self.installed_mods and self.installed_mods[mod_name]:
            latest_local = self.installed_mods[mod_name][-1]
            installed_ver = latest_local.version
            is_installed = True

            if not self.force_reinstall:
                # Check if installed version satisfies requirements
                dep_check = Dependency(name=mod_name, op=op or ">=", version=FactorioVersion(version_req) if version_req else release.version)
                if installed_ver >= release.version:
                    action = "KEEP"
                elif installed_ver < release.version:
                    action = "UPDATE"

        resolved_mod = ResolvedMod(
            name=mod_name,
            info=mod_info,
            release=release,
            is_root=is_root,
            is_already_installed=is_installed,
            installed_version=installed_ver,
            action=action,
        )

        if parent:
            if dep_type == DependencyType.REQUIRED:
                resolved_mod.required_by.add(parent)
            elif dep_type == DependencyType.RECOMMENDED:
                resolved_mod.recommended_by.add(parent)
            elif dep_type in (DependencyType.OPTIONAL, DependencyType.HIDDEN_OPT):
                resolved_mod.optional_by.add(parent)

        self.resolved[mod_name] = resolved_mod

        # Recursively resolve dependencies of this release
        for dep in release.dependencies:
            if dep.is_virtual:
                # Validate base version if target branch is known
                if dep.name == "base" and dep.version and self.target_factorio_branch:
                    target_v = FactorioVersion(self.target_factorio_branch)
                    if not dep.satisfies(target_v):
                        self.warnings.append(
                            f"Мод '{mod_name} v{release.version}' требует Factorio {dep.op} {dep.version}, "
                            f"но выбрана версия игры {self.target_factorio_branch}"
                        )
                continue

            if dep.is_conflict:
                continue

            should_resolve = False
            if dep.is_required:
                should_resolve = True
            elif dep.dep_type == DependencyType.RECOMMENDED and self.include_recommended:
                should_resolve = True
            elif dep.dep_type in (DependencyType.OPTIONAL, DependencyType.HIDDEN_OPT) and self.include_optional:
                should_resolve = True

            if should_resolve:
                self._resolve_mod_recursive(
                    mod_name=dep.name,
                    version_req=str(dep.version) if dep.version else None,
                    op=dep.op,
                    parent=mod_name,
                    dep_type=dep.dep_type,
                    is_root=False,
                )

    def _check_conflicts(self):
        """Check all resolved mods against each other for '!' incompatible dependencies."""
        all_mod_names = set(self.resolved.keys()) | set(self.installed_mods.keys())

        for mod_name, res_mod in self.resolved.items():
            for dep in res_mod.release.dependencies:
                if dep.is_conflict:
                    conflict_target = dep.name
                    if conflict_target in self.resolved:
                        self.conflicts.append(
                            (mod_name, conflict_target, f"Мод '{mod_name}' несовместим с '{conflict_target}'")
                        )
                        res_mod.action = "CONFLICT"
                        res_mod.conflict_reasons.append(f"Несовместим с {conflict_target}")
                    elif conflict_target in self.installed_mods and self.installed_mods[conflict_target]:
                        # Check if installed mod is enabled
                        if any(m.enabled for m in self.installed_mods[conflict_target]):
                            self.conflicts.append(
                                (
                                    mod_name,
                                    conflict_target,
                                    f"Мод '{mod_name}' несовместим с установленным '{conflict_target}'",
                                )
                            )
