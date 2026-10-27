# reqpack-plugin-gradle

ReqPack Lua wrapper plugin for Gradle.

Plugin manages plugin-owned synthetic dependency state plus shared Gradle cache.
It does not edit arbitrary user Gradle projects.

## Package Form

- `group:artifact:version`
- or `name = "group:artifact", version = "x.y.z"`

Version required for `install()` and `update()`.

## Supported Actions

- install tracked dependency into synthetic project and warm shared cache
- remove tracked dependency from synthetic project state
- update tracked dependency with `--refresh-dependencies`
- list tracked dependencies with best-effort resolved version output
- inspect one tracked or explicit dependency with `dependencyInsight`
- deterministic empty `search()` in v1
- deterministic empty `outdated()` in v1

## Runtime Paths

- synthetic state: `.reqpack-data/deps.json`
- synthetic project: `.reqpack-data/gradle-project/`
- shared cache: `.reqpack-data/gradle-user-home/`

## Limitations

- wrapper manages synthetic dependency state, not real project build files
- `installLocal()` unsupported in v1
- `search()` unsupported in v1 because Gradle CLI has no built-in artifact search
- `outdated()` unsupported in v1 for same reason

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
