# JBang ReqPack Plugin

Thin ReqPack wrapper for `jbang` app installs.

## Package Forms

- alias refs like `gavsearch@jbangdev`
- Maven coordinates like `group:artifact:version`
- URLs to scripts or jars
- local script or jar paths via `installLocal()` / request `localPath`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated` returns empty list in v1
- `search`
- `info`

## Runtime And Cache Paths

- JBang home: `${JBANG_DIR:-$HOME/.jbang}`
- JBang bin: `${JBANG_DIR:-$HOME/.jbang}/bin`
- JBang cache: `${JBANG_CACHE_DIR:-${JBANG_DIR:-$HOME/.jbang}/cache}`

## V1 Limits

- search only covers aliases visible to `jbang alias list`
- update is implemented as reinstall with `jbang app install --force`
- deep metadata from `jbang info tools` is not used because upstream format is experimental
- wrapper-script parsing is Unix-shell focused

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
