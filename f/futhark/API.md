# Futhark Plugin API

## Package Forms

- remote package path: `github.com/user/repo`
- remote package with explicit version: `{ name = "github.com/user/repo", version = "1.2.3" }`
- major-qualified package path: `github.com/user/repo@2`

## Supported Actions

- `install(context, packages)`
  - `futhark pkg add <pkg> [version]`
  - then `futhark pkg sync`
- `installLocal(context, path)`
  - unsupported in v1
- `remove(context, packages)`
  - `futhark pkg remove <pkg>`
  - then `futhark pkg sync`
- `update(context, packages)`
  - `futhark pkg upgrade`
  - then `futhark pkg sync`
- `list(context)`
  - parses `futhark.pkg`
- `outdated(context)`
  - compares manifest versions against newest remote git tag
- `search(context, prompt)`
  - searches cached metadata files only
- `info(context, name)`
  - fetches remote git tags and cached metadata for one package
- `resolvePackage(context, package)`
  - normalizes package path and enriches metadata

## Runtime And Cache Paths

- project root: `cwd` flag or current working directory
- manifest path: `<cwd>/futhark.pkg`
- install root: `<cwd>/lib/`
- metadata cache root: `<cwd>/.reqpack-data/futhark/metadata/`
- override cache root with `cache-root=<path>`

## v1 Limits

- `search()` has no global upstream catalog backing
- `info()` only knows versions derivable from git tags like `v1.2.3`
- packages with no release tags are not shown as outdated
- plugin does not parse full remote manifests for transitive package info in v1

## Test Command

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
