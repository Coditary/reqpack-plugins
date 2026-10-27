# conan API

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Flags

- `remote=<name>`
- `query=<package_query>`
- `recipe-only`

## Behavior summary

- `install` wraps `conan download` into local Conan cache
- `installLocal` wraps `conan export`
- `remove` wraps `conan remove --confirm`
- `update` re-downloads requested references from remote into cache
- `list` shows local Conan cache recipes and packages
- `search` shows remote recipe references
- `info` prefers local cache, then remote search
- `outdated` returns empty in v1 because Conan has no generic installed-vs-remote update query
