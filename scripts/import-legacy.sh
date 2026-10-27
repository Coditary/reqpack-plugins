#!/usr/bin/env bash
# One-time / repeatable import from ~/Dev/Coditary/plugins/reqpack into letter buckets.
set -euo pipefail

LEGACY_ROOT="${LEGACY_ROOT:-$HOME/Dev/Coditary/plugins/reqpack}"
DEST_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$LEGACY_ROOT" ]]; then
  echo "legacy root not found: $LEGACY_ROOT" >&2
  exit 1
fi

imported=0
for src in "$LEGACY_ROOT"/*; do
  [[ -d "$src" ]] || continue
  name="$(basename "$src")"
  [[ "$name" == "README.md" ]] && continue
  bucket="${name,,}"
  bucket="${bucket:0:1}"
  [[ "$bucket" =~ [a-z] ]] || bucket="_"
  dest="$DEST_ROOT/$bucket/$name"
  mkdir -p "$dest"
  rsync -a --delete \
    --exclude '.git/' \
    --exclude '.git' \
    "$src/" "$dest/"
  imported=$((imported + 1))
done

echo "imported $imported plugins into $DEST_ROOT"
