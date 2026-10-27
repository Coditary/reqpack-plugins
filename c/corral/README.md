# Corral

ReqPack wrapper plugin for Pony `corral` bundle dependencies.

## Package Forms

- remote git locator: `github.com/ponylang/valbytes.git`
- remote git locator with bundle path: `github.com/org/repo.git/subbundle`
- local git bundle: `../pony-inspect.git`
- local direct bundle: `../pony-inspect`

Optional request fields:

- `version`
- `revision`
- `flags = { "revision=<value>" }`

## Supported Actions

- `install`: add direct dependency to shared Corral cache bundle, then run `corral update`
- `installLocal`: same as install, using local path locator
- `remove`: remove direct dependency, clean `_corral`, then update remaining deps
- `update`: refresh all cached deps or replace one direct dep declaration then update
- `list`: list direct deps from shared cache bundle
- `info`: show cached direct dep info from shared bundle state
- `search`: returns empty list in v1 because Corral has no search command
- `outdated`: returns empty list in v1 because Corral has no deterministic outdated command

## Runtime And Cache Paths

- shared bundle root: `~/.cache/reqpack/corral/bundle`
- manifest: `~/.cache/reqpack/corral/bundle/corral.json`
- lock file: `~/.cache/reqpack/corral/bundle/lock.json`
- repo cache: `~/.cache/reqpack/corral/bundle/_repos`
- working tree: `~/.cache/reqpack/corral/bundle/_corral`

## v1 Limitations

- no remote search backend
- no remote package metadata lookup beyond cached state
- no outdated detection
- wraps plugin-owned shared bundle, not arbitrary user project bundles

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
