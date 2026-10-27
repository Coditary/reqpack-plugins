# Gradle Wrapper API

Short operator-facing reference for `gradle` wrapper.

## Package Semantics

- package name should be Maven coordinate base: `group:artifact`
- package version should be explicit for install/update
- wrapper stores tracked direct dependencies in plugin-owned `deps.json`

## Actions

- `install(context, packages)`:
  - rewrite tracked state
  - regenerate synthetic `build.gradle`
  - run `gradle dependencies --configuration reqpack`
- `installLocal(context, path)`:
  - returns failure; unsupported in v1
- `remove(context, packages)`:
  - rewrite tracked state only
- `update(context, packages)`:
  - rewrite tracked state
  - rerun Gradle with `--refresh-dependencies`
- `list(context)`:
  - read tracked state
  - best-effort `dependencyInsight` per dependency
- `outdated(context)`:
  - returns empty list in v1
- `search(context, prompt)`:
  - returns empty list in v1
- `info(context, name)`:
  - inspect tracked dependency or explicit `group:artifact:version`

## Shared Cache

All Gradle commands use one shared user home:

```text
.reqpack-data/gradle-user-home
```

Synthetic build root:

```text
.reqpack-data/gradle-project
```

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
