# rtx Plugin API

## Behavior

- `install(packages)` runs `rtx|mise install` once per package
- `installLocal(path)` runs `rtx|mise link <tool@version> <path>`
- `remove(packages)` runs `rtx|mise uninstall` for matched installed versions
- `update(packages)` runs `rtx|mise upgrade`
- `list()` reads `rtx|mise ls --installed --json`
- `outdated()` compares installed versions against `rtx|mise latest`
- `search(prompt)` parses `rtx|mise search --no-header`
- `info(name)` merges installed state, exact search row, and latest remote version

## Supported Flags

- `cache-root=<path>`
- `force`
- `jobs=<n>`
- `raw`
- `minimum-release-age=<value>`
- `bump` for `update()`
- `all` for `update()` with no packages
- `name=<tool>` for `installLocal()`
- `version=<version>` for `installLocal()`
- `match-type=<equal|contains|fuzzy>` for `search()`
- `limit=<n>` for `search()`

## Output Enrichment

Returned package items may include:

- `extraFields.installPath`
- `extraFields.source`
- `extraFields.requested`
- `extraFields.binary`

## v1 Limits

- current upstream writes and env names are `mise`, not legacy `rtx`
- `search()` uses registry rows, not full remote metadata
- `info()` derives rich output by composing several CLI commands
- `installLocal()` is symlink-based `link`, not archive extraction
