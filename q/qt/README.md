# Qt

ReqPack wrapper for official Qt Installer Framework command line.

## Package Forms

- exact Qt component ids like `qt.qt6.6111.linux_gcc_64`
- exact alias ids like `qt6.11.1-sdk`
- local artifacts for `installLocal()`: `.qbsp`, `.7z`

## Supported Actions

- `install()`
- `installLocal()`
- `remove()`
- `update()`
- `list()`
- `outdated()`
- `search()`
- `info()`

## Runtime And Cache Paths

Default shared state root:

- `q/qt/.reqpack-data/`

Inside root:

- `qt-root/` shared Qt installation root
- `cache/` Qt metadata cache via `--cache-path`
- `downloads/` downloaded online installer payloads

Override with flag:

- `data-root=/path`

Useful flags:

- `maintenance-tool=/path`
- `installer-url=https://...`
- `mirror=https://...`
- `repository=https://...`
- `temp-repository=https://...`
- `email=user@example.com`
- `pw=secret`

## Major V1 Limits

- Linux-first bootstrap path uses Qt Linux online installer by default
- `install()` expects exact Qt package or alias ids
- `info()` is synthesized from `list()` and exact `search()` matches because Qt CLI has no direct info command
- `installLocal()` needs existing `MaintenanceTool`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
