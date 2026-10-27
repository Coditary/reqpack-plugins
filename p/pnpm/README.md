# pnpm

ReqPack Lua wrapper plugin for `pnpm`.

## Package Forms

- registry package: `lodash`
- scoped package: `@types/node`
- exact version: `lodash@4.17.21`
- local folder or tarball in `installLocal()`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime / Cache Paths

- pnpm shared store: `pnpm store path`
- pnpm global root: `pnpm root --global`
- typical home path: `~/.local/share/pnpm`

Plugin does not keep its own metadata cache. It reads pnpm state directly.

## v1 Limits

- workspace graph semantics only passed through as flags
- no plugin-private persistence
- query actions return direct dependencies only for `list`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
