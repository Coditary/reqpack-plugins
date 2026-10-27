# teacup

ReqPack Lua wrapper for Tcl `teacup` package management.

## Package forms

- `name`
- `name` with explicit `version`
- `name` with explicit `entity=<package|application|profile|redirect>` flag
- local artifact path through `installLocal()`

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime and cache paths

- shared cache root: `~/.cache/reqpack/teacup`
- isolated Teacup repository: `~/.cache/reqpack/teacup/repository`
- ReqPack cached installed list: `~/.cache/reqpack/teacup/reqpack/last-list.txt`

## v1 limitations

- all installs/removals operate on isolated ReqPack-owned Teacup repository, not user default repo
- `search()` uses `teacup list <prompt>` fuzzy lookup instead of raw Teacup query syntax
- targeted `update(packages)` reuses `teacup install` because Teacup has no dedicated per-package update command
- no wrapper support for zero-arg `teacup remove` full repository wipe

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
