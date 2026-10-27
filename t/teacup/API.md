# teacup API

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Flags

- `entity=<package|application|profile|redirect>`
- `force`

## Behavior summary

- all local state lives under `~/.cache/reqpack/teacup`
- all local repo mutations and installed-state reads use `--at <repo>` with isolated Teacup repository
- `list()` reads installed packages from `teacup list --at-default --at <repo>` and caches raw output
- `outdated()` uses `teacup list --only newer --at <repo>`
- `search()` uses `teacup list <prompt>` for documented fuzzy lookup behavior
- `info()` combines `teacup describe --all <name>` with `teacup list <name>`
