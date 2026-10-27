# rqp-plugin-elan

ReqPack Lua wrapper plugin for Lean toolchains through `elan`.

Supports:

- install, local install, remove, update, list, outdated, search, and info
- honest mapping of ReqPack packages to `elan` toolchains
- shared state rooted in native `ELAN_HOME` instead of plugin-owned duplicate cache
- default and active toolchain metadata surfaced from native `elan` state

## Bundle Layout

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: plugin bundle manifest
- `run.lua`: `elan` wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `API.md`: behavior summary
- `.reqpack-test/core/*.lua`: hermetic conformance cases
- `docs/superpowers/specs/...`: design spec used for implementation

## Behavior

- ReqPack package means one Lean toolchain managed by `elan`
- installs use `elan toolchain install <toolchain>`
- local install uses `elan toolchain link <name> <path>`
- remove uses `elan toolchain uninstall <toolchain>`
- update reuses native install behavior to refresh alias-like toolchains
- query paths combine `elan toolchain list`, `elan show`, and `elan dump-state --no-net`
- `search()` is intentionally local/non-exhaustive because `elan` has no native remote catalog search

## Runtime And Cache Paths

- shared root: `ELAN_HOME` or `~/.elan`
- installed toolchains: `ELAN_HOME/toolchains`
- default and override state: `ELAN_HOME/settings.toml`
- temporary/downloader state: `ELAN_HOME/tmp`

No plugin-specific cache is created in v1.

## Package Forms

- channels: `stable`, `beta`, `nightly`
- dated channels: `nightly-2023-09-06`
- explicit releases: `4.3.0`, `v4.3.0`
- explicit origin + release: `leanprover/lean4:v4.9.0`
- linked local toolchains: custom names like `lean-dev`

## Major v1 Limitations

- `search()` is not a full remote catalog query because upstream `elan` does not provide one
- `outdated()` stays conservative and may return empty when no honest stale signal exists
- `installLocal()` needs a toolchain name or derives one from path basename

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
