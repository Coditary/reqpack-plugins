# Go ReqPack Plugin

ReqPack wrapper for Go CLI.

## Package Forms

- `tool`: executable package path like `golang.org/x/tools/cmd/stringer`
- `module`: module path like `golang.org/x/text`

If `packageType` is omitted, plugin defaults to `tool`.

## Supported Actions

- install Go tools with `go install path@version`
- install local Go command paths with `go install <path>`
- warm module cache with `go mod download`
- list installed tools from plugin-owned `bin/`
- list tracked modules from plugin-owned state
- lookup exact module info with `go list -m -json`
- report outdated tracked modules and resolvable tools

## Shared Runtime And Cache Paths

- default root: `~/.cache/reqpack/go`
- override: `cache-root=<path>` flag
- binaries: `<root>/bin`
- GOPATH: `<root>/gopath`
- module cache: `<root>/gomodcache`
- build cache: `<root>/gocache`
- tracked modules: `<plugin>/ .reqpack-data/modules.txt`

## v1 Limits

- `search()` only does exact module lookup, not broad registry search
- tool outdated detection depends on resolving containing module path
- remove leaves shared module cache warm

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
