# Leiningen ReqPack Plugin

Thin ReqPack wrapper for Leiningen artifact search and local Maven repository management.

## Package Forms

- remote/search coordinate: `cheshire` or `ring/ring-json`
- local install request: local `.jar` plus coordinate and version metadata

## Supported Actions

- `search()` via `lein search`
- `list()` from local Maven repository
- `info()` from local Maven repository, with `lein search` fallback
- `installLocal()` via `lein localrepo install`
- `remove()` by deleting exact local repository paths
- `outdated()` returns empty list in v1

## Runtime And Cache Paths

- shared artifact cache: `~/.m2/repository`
- shared query cache: `~/.cache/reqpack/leiningen`
- optional overrides via flags: `repo-root=/path`, `cache-root=/path`

## Major v1 Limitations

- no generic remote install for arbitrary coordinates
- `installLocal()` requires `lein-localrepo` task to be available
- `update()` for arbitrary artifacts not supported

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
