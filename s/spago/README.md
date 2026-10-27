# Spago ReqPack Plugin

ReqPack Lua wrapper for Spago workspace dependency management and PureScript Registry queries.

## Package forms

- direct dependency names like `prelude`, `effect`, `halogen`

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `search`
- `info`
- `outdated` returns empty list in v1

## Runtime and cache paths

- workspace cache: `.spago`
- workspace lockfile: `spago.lock`
- global cache: usually `~/.cache/spago-nodejs` on Linux
- exact paths available via `spago ls paths --json`

## Major v1 limitations

- requires running inside valid Spago workspace for install/remove/update/list
- no local artifact install support
- `outdated()` is intentionally empty because Spago does not expose reliable per-package outdated data

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
