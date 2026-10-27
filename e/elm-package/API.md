# Elm Package Plugin API

ReqPack wrapper for legacy Elm packages managed by `elm-package`.

## Package Forms

- remote package: `elm-lang/core`
- remote package with explicit version: `elm-lang/core` + `version = "5.1.1"`

## Supported Actions

- `install(context, packages)`
  Uses `elm-package install --yes <name> [version]` per package
- `installLocal(context, path)`
  Unsupported in v1
- `remove(context, packages)`
  Removes dependency keys from local `elm-package.json` and deletes `elm-stuff/exact-dependencies.json`
- `update(context, packages)`
  Uses `elm-package install --yes` with optional package names
- `list(context)`
  Reads project `elm-stuff/exact-dependencies.json` or `elm-package.json`
- `outdated(context)`
  Compares local dependency versions with registry latest versions
- `search(context, prompt)`
  Filters `package.elm-lang.org/all-packages?elm-package-version=0.18`
- `info(context, name)`
  Uses registry summary plus `description` and `documentation` legacy endpoints

## Runtime And Cache Paths

- project root defaults to current directory, override with `cwd=<path>` or `project-root=<path>`
- ReqPack metadata cache defaults to `~/.cache/reqpack/elm-package`, override with `cache-root=<path>`
- Elm package artifacts stay in `~/.elm`

## v1 Limits

- no local artifact install support
- remove works at project manifest level because upstream has no uninstall command
- listing and outdated checks are project-scoped, not global user-scoped

## Test Command

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
