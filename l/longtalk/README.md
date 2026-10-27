# longtalk

ReqPack Lua wrapper plugin for Logtalk `packs`.

## Package Forms

- `pack`
- `registry::pack`
- optional exact version in request `version`, e.g. `2:1:0`

## Supported Actions

- `install`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Shared Cache And Runtime Paths

- `LOGTALKPACKS`
- default shared root: `~/logtalk_packs`
- installed packs: `~/logtalk_packs/packs`
- archive cache: `~/logtalk_packs/archives`

## Major v1 Limitations

- no registry management
- no generic `installLocal(path)` support
- requires installed Logtalk integration runner such as `swilgt`
- `remove` and `update` follow upstream pack-name oriented API

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
