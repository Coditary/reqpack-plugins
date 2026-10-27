# hbmk2

ReqPack Lua wrapper for Harbour `.hbc` package references via `hbmk2`.

## Package forms

- `hbct`
- `hbct.hbc`
- local `.hbc` path through `installLocal()`

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

- shared state root: `~/.cache/reqpack/hbmk2`
- tracked refs file: `~/.cache/reqpack/hbmk2/tracked-packages.txt`
- shared hbmk2 workdir: `~/.cache/reqpack/hbmk2/workdir`

## v1 limitations

- no remote package download support because upstream `hbmk2` does not provide one
- `install` and `update` manage tracked `.hbc` references and validate them with `--hbinfo`
- `search()` searches Harbour function providers, not package names directly
- `outdated()` always returns empty list

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
