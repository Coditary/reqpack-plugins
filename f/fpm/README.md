# reqpack-plugin-fpm

ReqPack Lua wrapper plugin for Fortran Package Manager `fpm`.

Plugin id is `fpm`.
Host dependency is declared through `sys:fpm`.

## Model

This wrapper treats `fpm` as project-oriented dependency and cache tooling.
It does not pretend `fpm` has a global installed-package database.

Registry packages are tracked in plugin-owned synthetic manifest:

```text
.reqpack-data/fpm-cache/fpm.toml
```

Then fetched through:

```text
fpm update --fetch-only
```

This lets real `fpm` populate its shared registry cache.

## Supported Operations

- install registry dependencies into plugin-owned desired state and fetch cache
- install local fpm project path with `fpm install --profile release`
- remove registry dependencies from plugin-owned desired state
- update selected or all tracked dependencies with `fpm update --fetch-only`
- list tracked dependencies
- search official fpm registry index
- inspect package metadata from official fpm registry index
- show outdated pinned dependencies compared to registry latest

## Request Shape

Registry package requests should use:

```lua
packages = {
  {
    name = "stdlib",
    version = "0.1.0",
    namespace = "fortran-lang",
    packageType = "library"
  }
}
```

Supported fields:

- `name`: required
- `version`: optional, `*`/missing means latest desired state
- `namespace`: recommended
- `extraFields.namespace`: accepted as fallback

All registry packages are treated as `library` in v1.

## Runtime Paths

- plugin synthetic manifest: `.reqpack-data/fpm-cache/fpm.toml`
- real shared registry cache: managed by `fpm` itself

## Limitations

- no editing of user project manifests
- no publish/build/run/test wrapper behavior
- no per-package shared-cache purge
- namespace may be required explicitly if registry metadata is ambiguous

## Testing

Run from plugin directory:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
