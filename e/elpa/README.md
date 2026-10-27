# rqp-plugin-elpa

ReqPack Lua wrapper plugin for Emacs Lisp packages through Emacs `package.el`.

Supports:

- GNU ELPA and NonGNU ELPA
- install, local install, remove, update, list, outdated, search, and info
- shared ReqPack-managed ELPA state under `~/.local/share/reqpack/elpa`

## Bundle Layout

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: plugin bundle manifest
- `run.lua`: ELPA wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `API.md`: ReqPack Lua plugin quick reference
- `.reqpack-test/core/*.lua`: hermetic conformance cases

## Behavior

- wrapper uses batch `emacs` and official `package.el` APIs
- package root, archive cache, config cache, and temp state share one ReqPack-owned root
- default archives are pinned to GNU ELPA and NonGNU ELPA
- local install supports `.el` and `.tar`
- `update` with no package list updates all outdated installed ELPA packages

## Runtime Paths

- package root: `~/.local/share/reqpack/elpa/elpa`
- cache root: `~/.local/share/reqpack/elpa/cache`
- config root: `~/.local/share/reqpack/elpa/config`
- temp root: `~/.local/share/reqpack/elpa/tmp`

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```

Run one case:

```bash
rqp test-plugin --plugin ./run.lua --case ./.reqpack-test/core/info.lua
```
