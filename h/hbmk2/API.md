# hbmk2 API

## Supported request forms

- `name = "hbct"`
- `name = "hbct.hbc"`
- `name = "/abs/path/custom.hbc"`
- `localPath = "/abs/path/custom.hbc"`

## Flags

- `data-root=/abs/path`: override shared plugin state root
- `cache-root=/abs/path`: alias of `data-root`

## Behavior summary

- `install()` adds tracked `.hbc` refs and validates them with `hbmk2 -hbcontainer --hbinfo`
- `installLocal()` supports only local `.hbc` files
- `remove()` removes tracked refs by package id
- `update()` revalidates tracked refs and can replace tracked refs by package id
- `list()` returns tracked refs only
- `search()` uses `hbmk2 -find` and returns package providers for matching Harbour functions
- `info()` resolves one `.hbc` ref and reads metadata from resolved file
- `outdated()` returns empty list

## Important paths

- tracked refs: `~/.cache/reqpack/hbmk2/tracked-packages.txt`
- shared workdir: `~/.cache/reqpack/hbmk2/workdir`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
