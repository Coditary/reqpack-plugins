# API

## Identity

- plugin id: `leiningen`
- package coordinate: `group/artifact` or plain `artifact`
- package type: `jar`

## Actions

- `install(context, packages)`
  - supports local-path installs only
  - remote installs fail explicitly
- `installLocal(context, path)`
  - supports local `.jar`
  - requires coordinate and version from request package or flags
  - runs `lein localrepo install <jar> <coord> <version>`
- `remove(context, packages)`
  - removes exact artifact paths from local Maven repository
- `update(context, packages)`
  - unsupported for arbitrary artifacts in v1
- `list(context)`
  - scans local Maven repository
- `outdated(context)`
  - returns empty list
- `search(context, prompt)`
  - parses `lein search` output
- `info(context, name)`
  - local repo lookup first, exact search fallback second

## Flags

- `repo-root=/path` override local Maven repository root
- `cache-root=/path` override ReqPack search cache root
- `coord=group/artifact` coordinate for `installLocal()` when not provided in package
- `version=x.y.z` version for `installLocal()` when not provided in package

## Notes

- shared cache source of truth is local Maven repository
- search cache is parser reuse only; artifact payloads stay in Maven repo
