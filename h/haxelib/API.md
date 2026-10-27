# Haxelib Plugin API

ReqPack wrapper for Haxe libraries managed by `haxelib`.

## Package Forms

- remote package: `lime`
- remote package with explicit version: `lime` + `version = "8.1.3"`
- local archive install: `/path/to/package.zip`

## Supported Actions

- `install(context, packages)`
  Uses `haxelib --quiet --global --always install <name> [version]`
- `installLocal(context, path)`
  Uses `haxelib --quiet --global --always install <zip-path>`
- `remove(context, packages)`
  Uses `haxelib --quiet --global remove <name> [version]`
- `update(context, packages)`
  Uses `haxelib --quiet --global --always update [name]`
- `list(context)`
  Uses `haxelib --quiet --global list`, `config`, and `libpath`
- `outdated(context)`
  Uses installed set from `list` and latest release from `info`
- `search(context, prompt)`
  Uses `haxelib --quiet search <prompt>` and enriches matches with `info`
- `info(context, name)`
  Uses `haxelib --quiet info <name>`

## Runtime And Cache Paths

- global shared repository root comes from `haxelib --global config`
- active package directory comes from `haxelib --global libpath <name>`
- plugin does not create a second metadata cache in v1; Haxelib repo remains shared store

## v1 Limits

- `installLocal()` supports `.zip` archives only
- search output quality depends on names returned by `haxelib search`
- `outdated()` skips dev/git-style current versions because Haxelib does not expose a cheap reliable compare for them

## Test Command

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
