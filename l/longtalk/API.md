# longtalk API

## Behavior

- wraps Logtalk `packs` package management
- uses shared `LOGTALKPACKS` root or `~/logtalk_packs`
- prefers `LONGTALK_RUNNER` or `LOGTALK_RUNNER`, otherwise probes common Logtalk integration scripts

## Request Mapping

- `name = "pack"` for unique pack
- `name = "registry::pack"` for explicit registry
- `version = "2:1:0"` for exact version
- `flags` may include `force`, `clean`, `verbose`, `update`, `checksig`, `no-checksum`, `incompatible`, `status=...`, `downloader=...`, `curl=...`, `wget=...`, `gpg=...`, `git=...`, `tar=...`

## Important Notes

- `list()` reports installed packs only
- `outdated()` uses upstream outdated query
- `search()` queries available packs across defined registries
- `info()` returns installed metadata when available, otherwise catalog metadata

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
