# uv ReqPack Plugin

ReqPack wrapper for `uv` global tool installs.

## Package Forms

- `ruff`
- `ruff` with `version = "0.6.9"`
- `package[extra]`
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

- cache root: `~/.cache/reqpack/uv`
- uv cache: `~/.cache/reqpack/uv/cache`
- tools dir: `~/.cache/reqpack/uv/tools`
- bin dir: `~/.cache/reqpack/uv/bin`

## Notes

- wraps `uv tool`, not project-local `uv add` / `uv sync`
- `search` and `info` use PyPI HTTP endpoints because `uv` has no native remote search command
- local installed-state comes from `uv-receipt.toml` and installed metadata files under shared tool dir

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
