# Go Plugin API

## Package Types

- `tool` default
- `module`

## Action Mapping

- `install(tool)` -> `go install <path>@<version>`
- `install(module)` -> `go mod download -json <module>@<version>`
- `installLocal(path)` -> `go install <path>`
- `remove(tool)` -> remove matching binary from shared `bin/`
- `remove(module)` -> remove tracked state entry only
- `update(tool)` -> same as install with requested/latest version
- `update(module)` -> rewrite tracked version + `go mod download -json`
- `list()` -> merged installed tools + tracked modules
- `outdated()` -> compare tracked/installed versions to `@latest`
- `search(prompt)` -> exact module lookup with `go list -m -json`
- `info(name)` -> installed tool metadata or exact module metadata

## Flags

- `cache-root=<path>` shared root for `bin`, `gopath`, `gomodcache`, `gocache`

## Runtime Notes

- commands run with `GO111MODULE=on`
- output locale pinned to `C`
- plugin does not mutate arbitrary user repositories
