# Carthage ReqPack API Notes

## Supported Actions

- `install`: updates `Cartfile`, then runs `carthage update`
- `installLocal`: adds local `git` or `binary` declaration, then runs `carthage update`
- `remove`: removes matching declaration, then runs `carthage update`
- `update`: optionally rewrites requested requirement, then runs `carthage update`
- `list`: merges `Cartfile` and `Cartfile.resolved`
- `outdated`: parses `carthage outdated --xcode-warnings`
- `search`: searches current project dependencies and explicit identifiers
- `info`: returns current project dependency or normalized explicit identifier

## Supported Flags

- `dir=/path`
- `home=/path`
- `platform=ios,macOS`
- `use-xcframeworks`
- `cache-builds`
- `no-use-binaries`
- `use-submodules`
- `use-netrc`
- `new-resolver`
- `use-ssh`

## Returned Metadata

- `packageType` is Carthage origin: `github`, `git`, or `binary`
- `status` is usually `declared`, `installed`, or `outdated`
- `extraFields` includes project path, manifest path, resolved path, requirement, source, and cache root

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
