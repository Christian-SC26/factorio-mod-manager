#!/usr/bin/env python3
"""
Factorio Mod Manager
Main CLI entrypoint.
"""

from __future__ import annotations
import argparse
import sys
from pathlib import Path

# Add project root to sys.path
sys.path.insert(0, str(Path(__file__).parent.resolve()))

from factorio_mm.cli import CLIApp, print_banner
from factorio_mm.i18n import i18n


def main():
    parser = argparse.ArgumentParser(
        prog="fmm",
        description="Factorio Mod Manager - Fast mod and modpack manager with dependency resolution",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  fmm install https://mods.factorio.com/mod/space-exploration
  fmm install Krastorio2 flib
  fmm profile save pyanodons
  fmm switch space-age
  fmm profiles
  fmm optional
  fmm export my-pack.json
  fmm import my-pack.json
  fmm (without arguments to launch interactive menu)
""",
    )

    parser.add_argument(
        "-d", "--dir",
        dest="mods_dir",
        type=Path,
        help="Path to Factorio mods directory (default: auto-detect)",
    )
    parser.add_argument(
        "-v", "--factorio-version",
        dest="factorio_version",
        type=str,
        help="Target Factorio version (e.g. 2.1, 2.0, 1.1). Default: auto-detect",
    )
    parser.add_argument(
        "-l", "--lang",
        dest="lang",
        choices=["en", "ru"],
        default=None,
        help="Language / Язык (en, ru)",
    )

    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Install
    p_install = subparsers.add_parser("install", aliases=["i", "add"], help="Install mods/modpacks by URL or name")
    p_install.add_argument("targets", nargs="+", help="Mod portal URLs or mod names")
    p_install.add_argument("--no-recommended", action="store_true", help="Do not install recommended '+' dependencies")
    p_install.add_argument("--optional", action="store_true", help="Install optional '?' dependencies")
    p_install.add_argument("-f", "--force", action="store_true", help="Force reinstall even if version matches")
    p_install.add_argument("-y", "--yes", action="store_true", help="Automatically confirm download without prompt")
    p_install.add_argument("--no-clean", action="store_true", help="Do not delete older versions of updated mods")

    # Switch / Profile
    p_switch = subparsers.add_parser("switch", aliases=["load"], help="Quickly switch to a saved modpack profile")
    p_switch.add_argument("profile_name", help="Profile name or index")

    p_profiles = subparsers.add_parser("profiles", help="List all saved profiles")

    p_profile = subparsers.add_parser("profile", help="Manage modpack profiles (save, load, list, delete)")
    p_profile_sub = p_profile.add_subparsers(dest="profile_action", help="Profile action")
    
    p_prof_save = p_profile_sub.add_parser("save", help="Save current mod setup as a profile")
    p_prof_save.add_argument("name", help="Profile name")

    p_prof_load = p_profile_sub.add_parser("load", aliases=["switch"], help="Load/switch to a profile")
    p_prof_load.add_argument("name", help="Profile name or index")

    p_prof_list = p_profile_sub.add_parser("list", aliases=["ls"], help="List all profiles")

    p_prof_del = p_profile_sub.add_parser("delete", aliases=["rm"], help="Delete a profile")
    p_prof_del.add_argument("name", help="Profile name")

    # List
    p_list = subparsers.add_parser("list", aliases=["ls"], help="List all installed mods")

    # Check
    p_check = subparsers.add_parser("check", aliases=["status"], help="Check updates for installed mods")

    # Update
    p_update = subparsers.add_parser("update", aliases=["up", "upgrade"], help="Update all installed mods")
    p_update.add_argument("-y", "--yes", action="store_true", help="Automatically confirm download without prompt")

    # Info
    p_info = subparsers.add_parser("info", help="Show detailed mod information")
    p_info.add_argument("target", help="Mod URL or name")

    # Optional mods
    p_optional = subparsers.add_parser("optional", aliases=["opt"], help="Browse & download optional mods for installed mods")

    # Enable
    p_enable = subparsers.add_parser("enable", help="Enable mod(s) in mod-list.json")
    p_enable.add_argument("mods", nargs="+", help="Mod names")

    # Disable
    p_disable = subparsers.add_parser("disable", help="Disable mod(s) in mod-list.json")
    p_disable.add_argument("mods", nargs="+", help="Mod names")

    # Remove
    p_remove = subparsers.add_parser("remove", aliases=["rm", "uninstall"], help="Remove mod(s)")
    p_remove.add_argument("mods", nargs="+", help="Mod names")

    # Export
    p_export = subparsers.add_parser("export", help="Export installed mods to file")
    p_export.add_argument("output", nargs="?", default=None, help="Output file (.json or .txt)")

    # Import
    p_import = subparsers.add_parser("import", help="Import and install mods from file")
    p_import.add_argument("input_file", help="Mod list file (.json or .txt)")
    p_import.add_argument("-y", "--yes", action="store_true", help="Automatically confirm download without prompt")
    p_import.add_argument("--optional", action="store_true", help="Install optional '?' dependencies")

    # Lang
    p_lang = subparsers.add_parser("lang", help="Set default language (en, ru)")
    p_lang.add_argument("language", choices=["en", "ru"], help="Language code (en, ru)")

    # Interactive
    p_interactive = subparsers.add_parser("interactive", aliases=["tui"], help="Start interactive menu")

    args = parser.parse_args()

    app = CLIApp(mods_dir=args.mods_dir, factorio_version=args.factorio_version, lang=args.lang)

    if args.command == "lang":
        i18n.set_lang(args.language)
        print(f"[OK] Language set to {args.language}")
        return

    if not args.command or args.command in ("interactive", "tui"):
        app.interactive_menu()
        return

    if args.command in ("install", "i", "add"):
        print_banner()
        app.print_env_info()
        app.cmd_install(
            targets=args.targets,
            include_recommended=not args.no_recommended,
            include_optional=args.optional,
            force_reinstall=args.force,
            yes=args.yes,
            clean_old=not args.no_clean,
        )
    elif args.command in ("switch", "load"):
        app.cmd_profile_switch(args.profile_name)
    elif args.command == "profiles":
        app.cmd_profile_list()
    elif args.command == "profile":
        if args.profile_action == "save":
            app.cmd_profile_save(args.name)
        elif args.profile_action in ("load", "switch"):
            app.cmd_profile_switch(args.name)
        elif args.profile_action in ("list", "ls"):
            app.cmd_profile_list()
        elif args.profile_action in ("delete", "rm"):
            app.cmd_profile_delete(args.name)
        else:
            app.cmd_profile_list()
    elif args.command in ("list", "ls"):
        app.cmd_list()
    elif args.command in ("check", "status"):
        app.cmd_check_updates(apply=False)
    elif args.command in ("update", "up", "upgrade"):
        print_banner()
        app.print_env_info()
        app.cmd_check_updates(apply=True, yes=args.yes)
    elif args.command == "info":
        app.cmd_info(args.target)
    elif args.command in ("optional", "opt"):
        app._interactive_optional_mods()
    elif args.command == "enable":
        app.cmd_enable_disable(args.mods, enable=True)
    elif args.command == "disable":
        app.cmd_enable_disable(args.mods, enable=False)
    elif args.command in ("remove", "rm", "uninstall"):
        app.cmd_remove(args.mods)
    elif args.command == "export":
        app.cmd_export(args.output)
    elif args.command == "import":
        print_banner()
        app.print_env_info()
        app.cmd_import(args.input_file, yes=args.yes, include_optional=args.optional)


if __name__ == "__main__":
    main()
