#!/usr/bin/env python3
"""
Factorio Mod Manager (FMM)
Main CLI and interactive entrypoint.
"""

from __future__ import annotations
import sys
from pathlib import Path

# Add project root to sys.path to support running directly or via symlink
sys.path.insert(0, str(Path(__file__).resolve().parent))

from factorio_mm.main import main

if __name__ == "__main__":
    main()
