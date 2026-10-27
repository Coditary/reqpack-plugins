# raco

ReqPack wrapper for Racket `raco pkg`.

## Package forms

- named catalog package like `shell-completion`
- local archive like `pkg.zip`, `pkg.tgz`, `pkg.tar.gz`, `pkg.plt`
- local package directory, installed via `--link`

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

- shared download cache: Racket `download-cache-dir`
- typical Linux cache path: `~/.cache/racket/download-cache`
- typical macOS cache path: `~/Library/Caches/Racket/download-cache`
- user package scope lives under Racket user add-on/package directories managed by `raco`

## v1 limits

- semantic package versions are usually unavailable from `raco pkg`; checksum used as version token
- `search()` enumerates catalog names then filters locally
- `outdated()` uses `update --dry-run` heuristics because `raco pkg` has no direct outdated-list command

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
