# vfp-pm API

## Actions

- `install(context, packages)`
- `installLocal(context, path)`
- `remove(context, packages)`
- `update(context, packages)`
- `list(context)`
- `outdated(context)`
- `search(context, prompt)`
- `info(context, name)`

## Supported package request fields

- `name`
- `version`
- `projectPath`
- `catalogPath`
- `bridgeCommand`

## Supported flags

- `cache-root=<path>`
- `catalog=<path>`
- `catalog-url=<url>`
- `project=<path>`
- `packages-xml=<path>`
- `bridge=<command>`

## Behavior notes

- `search()` and `info()` read FoxGet-compatible TSV catalog snapshots
- `list()` and `outdated()` describe current FoxPro project only
- `install()` resolves package metadata from catalog, then runs configured VFP bridge
- `installLocal()` supports local `.prg` installer files
- `update()` runs remove then install, matching documented FoxGet behavior

## Runtime paths

- cache root: `~/.cache/reqpack/vfp-pm/`
- catalog snapshot: `~/.cache/reqpack/vfp-pm/catalog/packages.tsv`
- bridge scripts/results: `~/.cache/reqpack/vfp-pm/bridge/`
- installed state: `<project>/Packages/packages.xml`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
