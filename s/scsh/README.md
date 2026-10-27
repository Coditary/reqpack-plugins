# scsh

ReqPack Lua wrapper plugin for `scsh-install-pkg`.

## Package forms

- remote token: `foo`
- local path: `/path/to/package-dir`

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime and cache paths

- default data root: `./.reqpack-data/scsh`
- test root: `${fixtureRoot}/.reqpack-data/scsh`
- installed index: `state/installed.tsv`
- shared catalog cache: `cache/catalog.tsv`

## Flags

- `data-root=<path>`
- `dest-dir=<path>`
- `catalog=<path>`
- `catalog-name=<label>`
- `phases=<value>`

## Major v1 limitations

- upstream `scsh-install-pkg` has no standard remote search/list/info API
- `list()` only shows packages tracked by ReqPack state
- `search()` and `info()` use optional cached TSV catalog snapshots
- `outdated()` returns empty when no catalog with versions is available

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
