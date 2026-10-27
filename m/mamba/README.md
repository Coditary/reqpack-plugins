# Mamba Plugin

ReqPack Lua wrapper for Mamba and Conda-compatible packages.

## Package forms

- `python`
- `python=3.12`
- `python==3.12`
- local files for `installLocal()`:
  - `.conda`
  - `.tar.bz2`
  - `.txt`
  - `.json`
  - `.yaml`
  - `.yml`

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

- target prefix: explicit `--prefix` passed by plugin, default `/` if none provided
- shared package cache: managed by Mamba itself
- common user state paths:
  - `~/.mamba`
  - `~/.conda`
  - `~/.cache/conda`

## Major v1 limitations

- single-prefix workflow only
- no first-class environment create/delete wrapper
- search/info use Mamba package metadata only; homepage/summary may be absent upstream

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
