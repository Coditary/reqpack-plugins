# rqp-plugin-eupm

ReqPack Lua wrapper plugin for Euphoria packages through `eupm`.

Supports:

- install, local install, remove, update, list, search, and info
- conservative line-based parsing of native `eupm` output
- shared native `eupm` state for installed/query operations
- `outdated()` returning empty list in v1 by design

## Bundle Layout

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: plugin bundle manifest
- `run.lua`: `eupm` wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `API.md`: behavior summary
- `.reqpack-test/core/*.lua`: hermetic conformance cases
- `docs/superpowers/specs/...`: design spec used for implementation

## Behavior

- wrapper assumes verb-style `eupm` CLI: `install`, `remove`, `update`, `list`, `search`, `info`
- wrapper reuses native `eupm` state instead of storing duplicate installed-package data
- no plugin-specific cache is used in v1 because native queries are sufficient
- local install forwards path directly to `eupm install`
- `update` with empty package list no-ops successfully
- optional probe mode can inspect real `eupm` help output and remap alternate verbs for current process

## Runtime And Cache Paths

- upstream/native package state: managed by `eupm`
- plugin-owned cache root: none in v1

## Probe Mode

If you later get a real `eupm` binary, you can enable lightweight CLI probing:

- env: `REQPACK_EUPM_PROBE=1`
- request/context flag: `probe`

Probe behavior:

- tries `eupm --help`, `eupm help`, and `eupm -h`
- looks for alternate verb names like `uninstall`, `upgrade`, `find`, `show`, `query`, `installed`
- remaps wrapper commands for current process when detected
- logs detected verb mapping through ReqPack logger

Diagnostic helper:

- `plugin.diagnoseEupm(context)` returns binary/probe/verb snapshot for current runtime

## Major v1 Limitations

- public upstream `eupm` documentation is sparse, so wrapper is based on conservative CLI assumptions
- `outdated()` returns empty list instead of guessing remote version semantics
- if actual upstream CLI differs, command strings and parsers may need adjustment

## Verification Findings

Live verification attempted against:

- OpenEuphoria site search and forum
- current `OpenEuphoria/euphoria` upstream source tree
- official 4.1.0 Linux release tarball

Result:

- no shipped `eupm` binary or script found
- no official public `eupm` help/manpage found

Because of that, wrapper is hardened for multiple plausible text output shapes, but full live command validation is still blocked until a real `eupm` binary/source is available.

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
