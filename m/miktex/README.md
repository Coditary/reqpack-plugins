# MiKTeX ReqPack Plugin

Thin ReqPack wrapper for MiKTeX package management.

## Package Forms

- package id: `amsfonts`
- package request with flags: `{ name = "amsfonts", flags = { "admin", "repository=https://mirror.example/tm/packages/" } }`

## Supported Actions

- `install`
- `installLocal` (unsupported in v1)
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime And Cache Paths

- MiKTeX user data typically under `~/.miktex/` or platform-specific MiKTeX roots
- ReqPack shared catalog cache under `XDG_CACHE_HOME/reqpack/miktex/` or `~/.cache/reqpack/miktex/`

## v1 Limitations

- does not bootstrap MiKTeX itself
- `outdated()` can only detect that updates exist, not enumerate package names from stable CLI output
- `installLocal()` returns unsupported

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
