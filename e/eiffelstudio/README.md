# rqp-plugin-eiffelstudio

ReqPack Lua wrapper plugin for EiffelStudio package management through `iron`.

Supports:

- install, local install, remove, update, list, search, and info
- native IRON cache/state reuse through `IRON_PATH` or `ISE_IRON_PATH`
- `estudio` registry alias for EiffelStudio launcher naming
- conservative plain-text parsing of `iron` output
- `outdated()` returning empty list in v1 because standard CLI version data is not reliable enough to compare hermetically

## Bundle Layout

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: plugin bundle manifest
- `run.lua`: `iron` wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `API.md`: behavior summary
- `.reqpack-test/core/*.lua`: hermetic conformance cases
- `docs/superpowers/specs/...`: design spec used for implementation

## Package Forms

- package name: `base`
- repository URI: `https://iron.eiffel.com/24.05/com.eiffel/library/base`
- local path or `file://` URI for local installs

## Behavior

- plugin id is `eiffelstudio`
- registry alias `estudio` maps to same plugin
- native package manager is `iron`, shipped with EiffelStudio
- wrapper does not manage EiffelStudio IDE/compiler features
- wrapper reuses native IRON repositories and installed-package state
- `update` uses conservative global catalog refresh via `iron update`

## Runtime And Cache Paths

- native IRON base: `IRON_PATH` when set
- native IRON base fallback: `ISE_IRON_PATH` when set
- native IRON base default: EiffelStudio user files versioned `iron/` directory
- plugin-owned cache root: none in v1

## Major v1 Limitations

- standard public IRON docs do not prove package-scoped `update <name>` syntax, so ReqPack `update()` uses global `iron update`
- standard CLI output shape varies by EiffelStudio version, so parser stays conservative
- `outdated()` returns empty list instead of guessing remote-vs-installed versions from ambiguous output

## Verification Findings

Live verification used:

- EiffelSoftware upstream repository
- Eiffel downloads page
- IRON upstream client and wiki docs bundled in EiffelStudio source tree

Result:

- `EiffelStudio` is IDE/distribution
- `estudio` is launcher/app binary naming in upstream source
- `iron` is actual package manager CLI for Eiffel packages and repositories

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
