# rqp-plugin-metacello

ReqPack Lua wrapper plugin for Metacello on Pharo.

Supports:

- shared Pharo image workflow for Metacello-driven installs
- explicit baseline or configuration loads from remote repositories
- local FileTree repository loads through `installLocal()`
- stateful `list`, `info`, `update`, and `outdated` based on one shared ReqPack-managed state file

## Bundle Layout

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: plugin bundle manifest
- `run.lua`: Metacello wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `API.md`: operator-facing behavior reference
- `.reqpack-test/core/*.lua`: hermetic conformance cases

## Behavior

- all actions target one shared image and cache root unless overridden by flags
- remote installs require explicit `repository=<spec>`
- `list()` reports tracked projects from plugin state and augments with Pharo query data when available
- `search()` is repository-scoped only; there is no global Metacello package catalog
- `remove()` is conservative and only forgets tracked project state after successful Pharo-side action

## Runtime Paths

- plugin data root: `~/.cache/reqpack/metacello` by default
- shared state file: `<data-root>/state/installed.json`
- generated Pharo scripts: `<data-root>/state/*.st`
- shared package cache: `<cache-root>/package-cache`

Override with flags like:

- `data-root=/path/to/data`
- `cache-root=/path/to/cache`
- `image-path=/path/to/Pharo.image`
- `base-image=/path/to/base/Pharo.image`

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```

Run one case:

```bash
rqp test-plugin --plugin ./run.lua --case ./.reqpack-test/core/list.lua
```
