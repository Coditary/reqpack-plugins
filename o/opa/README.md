# rqp-plugin-opa

ReqPack Lua wrapper plugin for MLstate Opa build targets through `opa`.

Supports:

- install, local install, remove, update, list, outdated, search, and info
- honest mapping of ReqPack packages to local Opa compiler inputs and generated artifacts
- advisory shared cache for known local targets without duplicating native install state
- conservative local-first query behavior because upstream Opa is compiler-oriented, not registry-oriented

## Bundle Layout

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: plugin bundle manifest
- `run.lua`: `opa` wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `API.md`: behavior summary
- `.reqpack-test/core/*.lua`: hermetic conformance cases
- `docs/superpowers/specs/...`: design spec used for implementation

## Behavior

- ReqPack package means one Opa local build target
- accepted targets: `.opa`, `.opack`, `.conf`, `.opx`, or directory containing one of them
- installs run native `opa` build commands
- remove deletes generated outputs only and preserves source files
- update rebuilds known local targets; no remote refresh exists
- list/search/info are local-first and use advisory cache plus filesystem state
- `outdated()` intentionally returns empty list in v1

## Runtime And Cache Paths

- native target outputs: alongside source target, e.g. `.opx`, `_build`, executable, `.api`
- plugin advisory cache root: `data-root/opa` when provided, otherwise `~/.local/share/reqpack/opa`
- cache file: `<cache-root>/inventory.tsv`

No duplicate install database beyond lightweight target inventory is created in v1.

## Package Forms

- source file: `./app.opa`
- grouped args: `./project.opack`
- package config: `./project.conf`
- compiled package: `./foo.opx`
- project dir containing one supported target

Optional request flags:

- `compile`
- `link`
- `autocompile`
- `api`
- `warn-error=root`

## Major v1 Limitations

- no remote package catalog search because upstream Opa does not expose one
- `outdated()` is always empty by design
- remove only deletes outputs that can be derived safely from target path and cached metadata
- directory install fails when multiple plausible Opa entrypoints exist

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
