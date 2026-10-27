# kxi

ReqPack wrapper for `kxi package`, KX local package manager for q/kdb+ package artifacts and installed package libraries.

## Package Forms

- package name: `mypkg`
- package name with version: `mypkg/1.0.0`
- local artifact path: `/path/to/mypkg-1.0.0.kxi`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated` returns empty list
- `search`
- `info`

## Runtime And Cache Paths

- package root: `KX_PACKAGE_PATH` or `~/.insights/packages`
- artifact root: `KX_ARTIFACT_PATH` or `~/.insights/artifacts`
- deployment root: `KX_DEPLOYMENT_PATH` or `~/.insights/deployments`

All commands pin same roots through env-prefixed `kxi package` invocations so install/query actions share one cache view.

## v1 Limits

- wraps local package/artifact flows only
- no enterprise remote `pull/push/remote-list/remote-remove`
- `outdated()` intentionally returns empty because generic remote version discovery is not reliable from local-only CLI state

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
