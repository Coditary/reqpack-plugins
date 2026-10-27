# reqpack-plugin-futhark

ReqPack Lua wrapper plugin for `futhark pkg`.

## Model

This wrapper keeps Futhark's real project-local behavior:

- manifest lives in `futhark.pkg`
- synced package files live in `lib/`
- installs, removes, and upgrades operate on current project

ReqPack adds one shared metadata cache for query paths:

- `info()`
- `search()`
- `outdated()`

Default cache root:

```text
<project>/.reqpack-data/futhark
```

Override with flag:

```text
cache-root=/path/to/cache
```

## Supported Operations

- add manifest dependencies with `futhark pkg add`
- sync project dependencies with `futhark pkg sync`
- remove manifest dependencies with `futhark pkg remove`
- upgrade manifest dependencies with `futhark pkg upgrade`
- list manifest dependencies from `futhark.pkg`
- compare manifest versions with remote git tags for outdated view
- inspect remote package versions from git tags
- search previously cached package metadata

## Package Forms

- remote package path: `github.com/diku-dk/array`
- remote package with explicit version: `github.com/diku-dk/array` + `version = "1.2.3"`
- major-qualified path: `github.com/user/repo@2`

## Runtime Paths

- manifest: `futhark.pkg`
- installed package root: `lib/<package-path>/`
- metadata cache: `.reqpack-data/futhark/metadata/`

## Limits

- no upstream local artifact install, so `installLocal()` returns unsupported
- no upstream package catalog, so `search()` only searches cached package metadata
- selected-package update not supported upstream; `update()` upgrades whole manifest then syncs

## Testing

Run from plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
