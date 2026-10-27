#!/usr/bin/env python3
"""Validate every ReqPack wrapper plugin under reqpack-plugins (letter-grouped layout)."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = (
    "metadata.json",
    "reqpack.lua",
    "run.lua",
    "scripts/install.lua",
    "scripts/remove.lua",
)

REQUIRED_META = ("formatVersion", "name", "version", "summary", "description", "license")


def letter_bucket(plugin_dir_name: str) -> str:
    if not plugin_dir_name:
        return "_"
    return plugin_dir_name[0].lower()


def iter_plugin_dirs() -> list[Path]:
    plugins: list[Path] = []
    for bucket in sorted(ROOT.iterdir()):
        if not bucket.is_dir() or bucket.name in ("scripts", ".git"):
            continue
        if len(bucket.name) != 1 or not bucket.name.islower():
            continue
        for plugin in sorted(bucket.iterdir()):
            if plugin.is_dir():
                plugins.append(plugin)
    return plugins


def validate_plugin(plugin_path: Path) -> list[str]:
    errors: list[str] = []
    for rel in REQUIRED_FILES:
        if not (plugin_path / rel).is_file():
            errors.append(f"missing {rel}")

    meta_path = plugin_path / "metadata.json"
    meta: dict | None = None
    if meta_path.is_file():
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"metadata.json: {exc}")
        else:
            if meta.get("formatVersion") != 1:
                errors.append(f"metadata.formatVersion must be 1 (got {meta.get('formatVersion')})")
            for key in REQUIRED_META[1:]:
                if not str(meta.get(key, "")).strip():
                    errors.append(f"metadata.{key} is empty")

    reqpack_path = plugin_path / "reqpack.lua"
    if reqpack_path.is_file():
        text = reqpack_path.read_text(encoding="utf-8", errors="replace")
        if "apiVersion" not in text:
            errors.append("reqpack.lua has no apiVersion")

    run_path = plugin_path / "run.lua"
    if run_path.is_file():
        text = run_path.read_text(encoding="utf-8", errors="replace")
        if "plugin" not in text and "getName" not in text:
            errors.append("run.lua does not look like a plugin entry (no plugin/getName)")

    if meta is not None:
        folder = plugin_path.name.lower()
        meta_name = str(meta.get("name", "")).lower()
        bucket = plugin_path.parent.name
        expected_bucket = letter_bucket(folder)
        if bucket != expected_bucket:
            errors.append(f"wrong bucket {bucket}/ (expected {expected_bucket}/)")
        if meta_name != folder:
            errors.append(f"metadata.name '{meta_name}' != directory '{folder}'")

    return errors


def main() -> int:
    strict = "--strict" in sys.argv
    plugins = iter_plugin_dirs()
    if not plugins:
        print("no plugins found under letter buckets", file=sys.stderr)
        return 1

    problems: list[tuple[str, list[str]]] = []
    warnings: list[tuple[str, list[str]]] = []

    for plugin_path in plugins:
        errs = validate_plugin(plugin_path)
        hard = [e for e in errs if not e.startswith("metadata.name")]
        soft = [e for e in errs if e.startswith("metadata.name")]
        if strict:
            hard.extend(soft)
            soft = []
        if hard:
            problems.append((str(plugin_path.relative_to(ROOT)), hard))
        if soft:
            warnings.append((str(plugin_path.relative_to(ROOT)), soft))

    print(f"plugins checked: {len(plugins)}")
    print(f"errors: {len(problems)}")
    print(f"name mismatches (warn): {len(warnings)}")

    for rel, errs in problems:
        print(f"\n{rel}")
        for e in errs:
            print(f"  - {e}")

    for rel, errs in warnings:
        print(f"\n{rel} [warn]")
        for e in errs:
            print(f"  - {e}")

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
