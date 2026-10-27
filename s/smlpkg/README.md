# smlpkg ReqPack Plugin

Thin ReqPack wrapper for `smlpkg`.

## Package Forms

- `github.com/diku-dk/sml-random`
- `github.com/diku-dk/sml-random@1.0.0` via ReqPack `version`

## Supported Actions

- `install`
- `remove`
- `update`
- `list`
- `outdated`
- `info`

`search` returns empty because upstream `smlpkg` has no search command.
`installLocal` is unsupported.

## Runtime And Cache Paths

- manifest: `./sml.pkg`
- vendored packages: `./lib/`
- upstream internal cache: managed by `smlpkg` itself

## v1 Limits

- project-local only
- `update` upgrades all manifest requirements, not selected subset
- remote metadata comes only from `smlpkg versions <package>`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
