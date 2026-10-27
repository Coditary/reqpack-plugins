# meson

ReqPack Lua wrapper for Meson WrapDB subprojects and local `.wrap` imports with one shared ReqPack-scoped workspace and package cache.

## Package forms

- `libgee`
- `glib`
- local `.wrap` file via `installLocal`

## Supported actions

- install remote WrapDB projects
- install local `.wrap` files
- remove managed wraps from ReqPack workspace
- update installed remote wraps
- list managed wraps
- inspect remote or installed wrap metadata
- search WrapDB
- detect outdated remote wraps

## Runtime and cache paths

- data root: `~/.local/share/reqpack/meson`
- cache root: `~/.cache/reqpack/meson`
- config root: `~/.config/reqpack/meson`
- workspace: `~/.local/share/reqpack/meson/workspace`
- subprojects: `~/.local/share/reqpack/meson/workspace/subprojects`
- state file: `~/.local/share/reqpack/meson/state.tsv`
- package cache: `~/.cache/reqpack/meson/package-cache`

## v1 limitations

- remote install/update follows Meson CLI latest wrap behavior; no direct remote `name@branch` install selector
- `remove` only removes ReqPack-managed workspace files, not shared package-cache artifacts
- `installLocal()` supports local `.wrap` files, not arbitrary source archives or directories

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
