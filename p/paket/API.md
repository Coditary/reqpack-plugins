# paket API

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
- `group`
- `project`
- `type` with `clitool`

## Supported flags

- `cache-root=<path>`
- `group=<name>`
- `project=<path>`
- `type=<nuget|clitool>`
- `source=<url>`
- `max=<n>`
- `force`
- `redirects`
- `clean-redirects`
- `create-new-binding-files`
- `keep-major`
- `keep-minor`
- `keep-patch`
- `touch-affected-refs`
- `only-referenced`
- `generate-load-scripts`
- `load-script-framework=<tfm>`
- `load-script-type=<csx|fsx>`
- `filter`
- `no-install`
- `ignore-constraints`
- `include-prereleases`

## Behavior notes

- v1 manages only Paket `nuget` dependencies inside ReqPack shared workspace
- `list()` and `outdated()` describe that shared workspace only
- `search()` uses `find-packages` and enriches with `find-package-versions`
- `info()` merges installed state with remote version list
- `installLocal()` supports `.nupkg` only and infers package id/version from filename

## Runtime paths

- workspace: `p/paket/.reqpack-data/workspace/`
- dependencies file: `p/paket/.reqpack-data/workspace/paket.dependencies`
- local feed: `p/paket/.reqpack-data/workspace/local-feed/`
- local archive cache: `p/paket/.reqpack-data/workspace/local-cache/`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
