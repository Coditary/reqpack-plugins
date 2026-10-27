# rqp-plugin-haxelib

ReqPack Lua wrapper plugin for Haxelib.

Supports:

- Haxe libraries from `lib.haxe.org`
- shared global Haxelib repository via `haxelib --global`
- remote search and package info via `haxelib search` and `haxelib info`
- local zip installs through `installLocal()`

## Bundle Layout

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: plugin bundle manifest
- `run.lua`: Haxelib wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `API.md`: operator-facing behavior reference
- `.reqpack-test/core/*.lua`: hermetic conformance cases

## Behavior

- all repo-sensitive commands use `--global` so ReqPack works against one shared Haxelib store
- `list()` uses `haxelib list`, `haxelib config`, and `haxelib libpath`
- `search()` starts from `haxelib search` then enriches each match with `haxelib info`
- `outdated()` compares installed current version with newest release reported by `haxelib info`
- `installLocal()` supports local `.zip` archives only in v1

## Runtime Paths

- shared repository root: `haxelib --global config`
- active package root: `haxelib --global libpath <name>`

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```

Run one case:

```bash
rqp test-plugin --plugin ./run.lua --case ./.reqpack-test/core/info.lua
```
