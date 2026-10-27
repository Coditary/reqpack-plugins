# guildhall

ReqPack Lua wrapper for Guildhall package management via `guild` subcommands.

## Package forms

- `name`
- `name=version`
- local bundle path through `installLocal()`

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

- shared home root: `~/.cache/reqpack/guildhall/home`
- install prefix: `~/.cache/reqpack/guildhall/home/.local`
- Guildhall cache: `~/.cache/reqpack/guildhall/home/.cache/guildhall`
- Guildhall database: `~/.cache/reqpack/guildhall/home/.local/var/lib/guildhall`

## v1 limitations

- remote actions need explicit `repo=<uri>` flag or `REQPACK_GUILDHALL_REPO`
- `search()` derived from `guild list-packages --all`
- `outdated()` derived from installed list plus per-package `guild show`
- `installLocal()` expects Guildhall bundle path

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
