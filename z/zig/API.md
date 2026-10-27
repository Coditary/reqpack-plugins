# zig Plugin API

## Behavior

- `install(packages)` runs `zig fetch` per URL/path package or `zig build --fetch` for project fetch mode
- `installLocal(path)` runs `zig fetch <path>`
- `remove(packages)` deletes ReqPack-managed records and managed mirror dirs only
- `update(packages)` re-runs prior fetch mode and refreshes managed records
- `list()` reads ReqPack-managed records from shared cache
- `search(prompt)` returns synthetic item for direct URL/path prompts
- `info(name)` returns managed record or synthetic URL/path info
- `outdated()` returns empty list

## Supported Flags

- `save`
- `save=<name>`
- `save-exact`
- `save-exact=<name>`
- `build-fetch`
- `build-fetch=all`
- `fetch-tree`
- `fetch-tree=all`

## Output Enrichment

Returned package items may include:

- `extraFields.sourceKind`
- `extraFields.installMode`
- `extraFields.target`
- `extraFields.globalCacheDir`
- `extraFields.recordsDir`
- `extraFields.mirrorPath`
- `extraFields.projectPath`
- `extraFields.requestedVersion`

## v1 Limits

- no global registry search because Zig has no native package search API
- no generic remote metadata lookup by short package name
- no unsafe deletion from shared content-addressed Zig global cache
