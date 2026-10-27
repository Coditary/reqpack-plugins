# rqp-plugin-elm-package

ReqPack Lua wrapper plugin for legacy `elm-package`.

Supports:

- project dependency install and update through `elm-package`
- project dependency removal by editing `elm-package.json`
- remote search and package info through `package.elm-lang.org` legacy endpoints
- outdated checks from local exact dependencies against remote registry

## Bundle Layout

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: plugin bundle manifest
- `run.lua`: `elm-package` wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `API.md`: operator-facing behavior reference
- `.reqpack-test/core/*.lua`: hermetic conformance cases

## Behavior

- project mutations require local `elm-package.json`
- `list()` prefers `elm-stuff/exact-dependencies.json`, then falls back to manifest dependencies
- `search()` filters cached or fetched legacy `all-packages` index
- `info()` enriches package data with legacy `description` and `documentation` payloads
- remote metadata cache lives under ReqPack cache root; package artifacts stay in Elm's shared `~/.elm`

## Runtime Paths

- project manifest: `elm-package.json`
- exact dependency lock: `elm-stuff/exact-dependencies.json`
- shared Elm package cache: `~/.elm`
- ReqPack metadata cache: `~/.cache/reqpack/elm-package`

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
