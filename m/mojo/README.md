# mojo

ReqPack plugin for legacy `modular` CLI Mojo installs.

## Package forms

- `mojo`
- query-only alias: `modular`

Mutating actions reject `modular` and only accept `mojo`.

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `outdated` (returns empty list because upstream has no reliable remote outdated query)
- `search`
- `info`

## Runtime and cache paths

- shared upstream cache root: `$MODULAR_HOME` or `$HOME/.modular`
- install root: `<modular-home>/pkg/packages.modular.com_mojo`
- binary path: `<modular-home>/pkg/packages.modular.com_mojo/bin/mojo`

## v1 limitations

- wraps legacy `modular` CLI behavior, not modern `pixi`/`uv` Mojo installs
- `installLocal()` unsupported because upstream has no local package artifact install flow
- `outdated()` cannot reliably detect newer remote releases

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
