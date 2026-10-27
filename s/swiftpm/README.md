# reqpack-plugin-swiftpm

ReqPack wrapper plugin for Swift Package Manager (`swift package`).

Plugin manages dependencies in one ReqPack-owned shared SwiftPM workspace.

## Scope

- installs remote package dependencies into shared workspace
- installs local package paths into shared workspace
- removes dependencies from shared workspace
- updates shared workspace dependencies
- lists current shared workspace dependencies
- derives outdated packages from package collection metadata
- searches package collections
- shows package info from installed state and package collections

## Runtime And Cache Paths

- workspace root: `~/.local/share/reqpack/swiftpm/workspace`
- plugin state: `~/.local/share/reqpack/swiftpm/dependencies.tsv`
- resolved file: `~/.local/share/reqpack/swiftpm/workspace/Package.resolved`
- SwiftPM cache: `~/.cache/reqpack/swiftpm/cache`
- SwiftPM scratch: `~/.cache/reqpack/swiftpm/scratch`
- SwiftPM config: `~/.config/reqpack/swiftpm/configuration`
- SwiftPM security: `~/.config/reqpack/swiftpm/security`

## Package Forms

- remote URL in `package.name`, for example `https://github.com/apple/swift-argument-parser.git`
- local package path through `installLocal()` or request `path`
- optional scoped registry identity with explicit requirement flags

Supported requirement flags:

- `exact`
- `from=<version>`
- `up-to-next-minor-from=<version>`
- `branch=<name>`
- `revision=<sha>`
- `to=<version>`
- `through=<version>`

Without explicit requirement flags, `package.version` is treated as `from` / up-to-next-major.

## Notes

- plugin wraps SwiftPM as shared workspace manager because SwiftPM is not a global installer
- `search()` and remote `info()` rely on configured package collections
- `list()` reports plugin-managed workspace state only
- `outdated()` skips local path dependencies and packages missing collection metadata

## Running Tests

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
