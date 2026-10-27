# rqp-plugin-cran

ReqPack Lua wrapper plugin for CRAN packages for R.

Supports:

- remote install from CRAN mirror
- local install from package archive or source directory
- managed package library under shared plugin data root
- `list`, `outdated`, `search`, and `info` from R package metadata

## Package Forms

- package name like `jsonlite`
- local archive like `./jsonlite_1.8.9.tar.gz`
- local source directory accepted by `install.packages(repos = NULL, ...)`

## Runtime Paths

Default state root:

- `.reqpack-data/library`
- `.reqpack-data/cache`
- `.reqpack-data/config`
- `.reqpack-data/tmp`

Override with request flag:

- `data-root=/path/to/state`

Optional mirror override:

- `repo=https://cloud.r-project.org`

## v1 Limitations

- remote install/update targets latest suitable CRAN release only
- archived historical versions are not resolved automatically
- one effective CRAN mirror per request

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
