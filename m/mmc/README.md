# mmc ReqPack Plugin

ReqPack plugin for Mercury libraries via `mmc --make`.

## Package forms

- `{ name = "foo", path = "/path/to/foo-lib" }`
- `{ path = "/path/to/foo-lib" }`
- `localPath=/path/to/foo-lib` via `installLocal`

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

- shared cache root: `~/.cache/reqpack/mmc`
- shared install prefix: `~/.cache/reqpack/mmc/install-prefix`
- tracked state: `~/.cache/reqpack/mmc/tracked.json`

Use `cache-root=/abs/path` to override root or `install-prefix=/abs/path` to override install target.

## Limitations

- v1 manages tracked local Mercury library source trees only
- no remote package download or registry search because upstream `mmc` does not provide one
- `remove` only deletes files under ReqPack-owned install prefix
- `outdated` returns empty list because upstream has no reliable version catalog

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
