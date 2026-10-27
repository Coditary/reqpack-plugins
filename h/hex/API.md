# hex API

## Inputs

### Common flags

- `dir=/path/to/project`: target Mix project directory
- `organization=<name>`: forwarded to supported Hex commands
- `repo=<name>`: forwarded where supported
- `version=<semver>`: used by `info()` when needed
- `cache-root=/custom/cache/root`: override shared cache root

### Install package fields

- `name`: Hex package name
- `version`: optional exact version or requirement source for dependency line
- `flags`: optional ReqPack flags such as `organization=...`, `repo=...`, `only=dev`, `optional=true`, `runtime=false`, `override=true`

### Local install

- `localPath`: local Mix dependency path
- optional flag `name=<app>` if local app name cannot be inferred from local `mix.exs`

## Action mapping

- `install` -> edit `mix.exs`, then `mix deps.get`
- `installLocal` -> add `path:` dep, then `mix deps.get`
- `remove` -> remove dep entry, then `mix deps.clean --unlock --unused`
- `update` -> optional dep rewrite, then `mix deps.update <name...>` or `mix deps.update --all`
- `list` -> `mix deps --all`
- `outdated` -> `mix hex.outdated --all --within-requirements`
- `search` -> `mix hex.package search <prompt>`
- `info` -> `mix hex.info <name> [version]`
- `resolvePackage` -> normalize request from `info()` result

## Output notes

- `list()` returns installed Hex dependencies only
- `outdated()` returns only dependencies with newer versions available
- `search()` returns remote Hex packages
- `info()` returns rich package metadata when available
- `resolvePackage()` returns normalized package identity and version hints for ReqPack

## Cache model

All commands share one cache root so Hex bootstrap, registry state, and archives are reused across actions and query-only flows.
