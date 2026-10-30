#!/usr/bin/env python3
"""Point monorepo wrapper plugins in rqp-registry at Coditary/reqpack-plugins."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = "git+https://github.com/Coditary/reqpack-plugins.git@main"


def monorepo_plugin_ids() -> set[str]:
    ids: set[str] = set()
    for bucket in ROOT.iterdir():
        if not bucket.is_dir() or len(bucket.name) != 1 or not bucket.name.islower():
            continue
        for plugin_dir in bucket.iterdir():
            if plugin_dir.is_dir() and (plugin_dir / "run.lua").is_file():
                ids.add(plugin_dir.name.lower())
    return ids


def update_registry_tree(registry_root: Path, source: str) -> tuple[int, int]:
    mono = monorepo_plugin_ids()
    updated = 0
    skipped = 0

    for path in sorted(registry_root.rglob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        name = str(data.get("name", "")).lower()
        if name not in mono:
            skipped += 1
            continue
        if data.get("alias") is True:
            skipped += 1
            continue
        if data.get("source") == source:
            skipped += 1
            continue
        data["source"] = source
        path.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
        updated += 1

    return updated, skipped


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: migrate-registry-sources.py /path/to/rqp-registry", file=sys.stderr)
        return 1

    registry_root = Path(sys.argv[1]).resolve() / "registry"
    if not registry_root.is_dir():
        print(f"registry directory not found: {registry_root}", file=sys.stderr)
        return 1

    source = DEFAULT_SOURCE
    updated, skipped = update_registry_tree(registry_root, source)
    print(f"monorepo plugins: {len(monorepo_plugin_ids())}")
    print(f"updated: {updated}")
    print(f"skipped: {skipped}")
    print(f"source: {source}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
