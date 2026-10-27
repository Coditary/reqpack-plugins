# zig ReqPack Plugin

ReqPack wrapper for Zig package fetch and dependency-tree cache warming.

## Package Forms

- source archive URL accepted by `zig fetch`
- git URL accepted by `zig fetch`
- local file path or local directory path
- project path with `flags = { "build-fetch" }` or `flags = { "build-fetch=all" }`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Shared Runtime Paths

- cache root: `~/.cache/reqpack/zig`
- shared Zig global cache: `~/.cache/reqpack/zig/global-cache`
- ReqPack records: `~/.cache/reqpack/zig/records`
- managed sources dir: `~/.cache/reqpack/zig/sources`

## Notes

- wraps real Zig package-manager commands, mainly `zig fetch` and `zig build --fetch`
- `list()` shows ReqPack-managed records only, not raw full Zig global cache contents
- `search()` only resolves direct URL/path prompts because Zig has no native global search API
- `outdated()` returns empty because Zig has no reliable cross-project outdated query

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
