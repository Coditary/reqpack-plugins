# raco API

## Commands

- install named packages: `raco pkg install --batch --scope user --deps search-auto <name> ...`
- install local dir: `raco pkg install --batch --scope user --deps search-auto --link <dir>`
- install local file: `raco pkg install --batch --scope user --deps search-auto <path>`
- remove: `raco pkg remove --batch --scope user <name> ...`
- update selected: `raco pkg update --batch --scope user --deps search-auto <name> ...`
- update all: `raco pkg update --batch --scope user --deps search-auto --all`
- list installed: `raco pkg show --all --long -d --scope user`
- inspect catalog item: `raco pkg catalog-show <name>`

## Output notes

- installed package `version` maps to checksum when no semantic version exists
- remote `latestVersion` maps to catalog checksum when available
- `extraFields` includes scope, source, directory, auto-installed marker, author, tags, ring, and modules when known

## Search behavior

`search()` runs:

1. `raco pkg catalog-show --all --only-names`
2. local substring filter on package names
3. `raco pkg catalog-show <name> ...` for first 25 matches

## Local install behavior

- directories use `--link`
- existing files install directly and let `raco` infer package source type
