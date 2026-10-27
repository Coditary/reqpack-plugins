# rtx ReqPack Plugin

ReqPack wrapper for `rtx-cli` tool installs.

Current upstream project was renamed to `mise`. This plugin keeps ReqPack system name `rtx`, prefers `rtx` binary when present, and falls back to `mise`.

## Package Forms

- `node`
- `node` with `version = "20"`
- `python` with `version = "3.12"`
- backend-qualified names like `github:cli/cli`
- local path via `installLocal()`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Shared Runtime Paths

- root: `~/.cache/reqpack/rtx`
- data dir: `~/.cache/reqpack/rtx/data`
- cache dir: `~/.cache/reqpack/rtx/cache`
- state dir: `~/.cache/reqpack/rtx/state`
- config dir: `~/.cache/reqpack/rtx/config`
- tmp dir: `~/.cache/reqpack/rtx/tmp`

## Notes

- installs are localized through `MISE_*` and `RTX_*` env vars under one ReqPack-managed root
- `installLocal()` maps to `rtx|mise link`, so exact local identity should be passed with flags like `name=node` and `version=custom`
- `search()` and `info()` compose registry search, installed-state, and `latest` because upstream has no dedicated rich package info command

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
