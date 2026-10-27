# reqpack-plugin-swiftpm API

## Supported Actions

- `install(packages)` -> render shared manifest + `swift package resolve`
- `installLocal(path)` -> add `.package(path: ...)` + `swift package resolve`
- `remove(packages)` -> remove entries + re-resolve shared workspace
- `update(packages)` -> optional requirement rewrite + `swift package update`
- `list()` -> plugin state + `Package.resolved`
- `outdated()` -> installed versions + `swift package-collection describe --json`
- `search(prompt)` -> `swift package-collection search --json --keywords <prompt>`
- `info(name)` -> installed state merge + `swift package-collection describe --json`

## Returned Metadata

Items expose `extraFields` when known:

- `source`
- `requirementKind`
- `requirementValue`
- `requirementUpperBound`
- `workspacePath`
- `manifestPath`
- `resolvedPath`
- `cacheRoot`
- `configRoot`
- `securityPath`
- `scratchPath`
- `revision`
- `branch`
- `summary`
- `readmeURL`
- `license`

## Limitations

- no direct mutation of arbitrary user `Package.swift`
- no stable upstream remove-dependency command; plugin rewrites its own managed manifest
- remote search/info/outdated depend on configured Swift package collections

## Test Command

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
