# API

## Behavior summary

- `install`: `yarn global add`
- `installLocal`: `yarn global add file:<path>`
- `remove`: `yarn global remove`
- `update`: `yarn global upgrade --latest`, or exact `add` when version pinned
- `list`: reads global manifest and enriches with `yarn global list --json`
- `outdated`: runs `yarn outdated --json` inside Yarn global dir
- `search`: queries npm registry search API
- `info`: uses `yarn info --json` and overlays installed/global state

## Notes

- plugin returns common Yarn paths in `extraFields`: `globalDir`, `binDir`, `cacheDir`
- package type is always `package`
- non-Classic Yarn versions are query-only for now

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
