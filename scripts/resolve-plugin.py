#!/usr/bin/env python3
"""Resolve plugin id to absolute path (letter-grouped layout)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def resolve(plugin_id: str) -> Path:
    normalized = plugin_id.strip().lower()
    if not normalized:
        raise SystemExit("empty plugin id")
    bucket = normalized[0]
    path = ROOT / bucket / normalized
    if path.is_dir() and (path / "run.lua").is_file():
        return path.resolve()
    raise SystemExit(f"plugin not found: {plugin_id} (looked at {path})")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: resolve-plugin.py <plugin-id>")
    print(resolve(sys.argv[1]))


if __name__ == "__main__":
    main()
