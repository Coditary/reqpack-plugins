# Spago Plugin API

## Commands used

- `spago install <pkg...>`
- `spago uninstall <pkg...>`
- `spago upgrade`
- `spago ls deps --json --transitive`
- `spago ls packages --json`
- `spago ls paths --json`
- `spago registry search --json <prompt>`
- `spago registry info --json <name>`

## Behavior summary

- `install()` adds direct dependencies to current workspace package
- `remove()` removes direct dependencies from current workspace package
- `update()` upgrades current workspace build plan
- `list()` returns workspace-visible dependencies, enriched with cache paths when available
- `search()` queries registry package names and latest version metadata
- `info()` returns rich registry metadata for one package
- `outdated()` returns empty list in v1
- `installLocal()` is unsupported in v1

## Request notes

- package names should use Spago / registry package ids without `purescript-` prefix
- mutating actions require valid `spago.yaml` workspace context
