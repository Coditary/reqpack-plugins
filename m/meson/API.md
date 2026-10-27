# meson API

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Flags

- `data-root=<path>`
- `cache-root=<path>`
- `config-root=<path>`

## Behavior summary

- `install` runs `meson wrap install <name>` in ReqPack-managed workspace
- `installLocal` copies local `.wrap` file into managed `subprojects/`
- `remove` deletes managed wrap file, extracted subproject directory, and state entry
- `update` runs `meson wrap update <name>` for managed remote wraps
- `list` reads ReqPack-managed `state.tsv`
- `outdated` parses `meson wrap status`
- `search` parses `meson wrap search`
- `info` parses `meson wrap info` and merges installed state when available
- all Meson commands use pinned ReqPack-scoped env and shared `MESON_PACKAGE_CACHE_DIR`
