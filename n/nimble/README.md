# reqpack-plugin-nimble

ReqPack wrapper plugin for Nimble.

Plugin manages Nim ecosystem packages through `nimble` CLI.

## Package Forms

- package name: `jester`
- version selector: `jester@0.6.0`
- VCS selector: `jester@#head`
- repository URL accepted by Nimble
- local package directory
- local `.nimble` file

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `search`
- `info`
- `outdated` returns empty list in v1

## Runtime And Cache Paths

- shared Nimble home: `~/.nimble`
- installed packages: `~/.nimble/pkgs*`
- package cache: `~/.nimble/pkgcache`
- installed binaries: `~/.nimble/bin`
- managed Nim toolchains: `~/.nimble/nim`

Wrapper reuses Nimble shared cache/state. No plugin-specific cache.

## v1 Limitations

- wraps Nimble package manager for Nim ecosystem, not CRAN R package named `nimble`
- `list()` returns installed packages only
- `outdated()` returns empty list because Nimble has no cheap reliable installed-vs-remote update query
- `info()` returns installed-path enrichment for installed packages and exact-match search metadata for remote packages

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
