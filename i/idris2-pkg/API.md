# API

## Wrapped CLI

- binary: `pack`
- upstream: `https://github.com/stefan-hoeck/idris2-pack`

## Command mapping

- install libraries: `pack install <name>...`
- install local project deps: `pack install-deps <path.ipkg>`
- remove libraries: `pack remove <name>...`
- refresh and update pack: `pack update-db` then `pack update`
- search collection: `pack --short-desc query <prompt>`
- inspect package: `pack --long-desc query <name>`

## Returned behavior

- `list()` reads ReqPack manifest of successful plugin-managed installs
- `search()` returns collection matches from `pack query`
- `info()` merges collection detail output with manifest-installed state when available
- `outdated()` returns `[]`

## Local install

- accepts `.ipkg` only
- runs dependency install for local Idris project
- stores manifest row as `local-project`
