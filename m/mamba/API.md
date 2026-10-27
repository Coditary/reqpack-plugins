# Mamba Plugin API

## Request flags

Supported `package.flags` tokens:

- `channel=<name-or-url>`
- `override-channels`
- `no-deps`
- `only-deps`
- `force-reinstall`
- `freeze-installed`
- `allow-downgrade`

## Search prompt forms

- plain: `zlib`
- channel-scoped: `channel:conda-forge zlib`
- local-only: `local:zlib`

## Behavior summary

- mutation commands run per package so flags stay attached to each request
- query commands use `--json`
- `list()` returns installed packages in selected prefix
- `outdated()` compares installed items with newest remote candidate from `mamba search --json`
- `info()` merges installed state with remote metadata when available
- `installLocal()` supports Conda artifacts and spec files only

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
