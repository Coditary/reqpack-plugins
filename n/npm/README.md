# rqp-plugin-npm

ReqPack Lua plugin for global npm packages.

Plugin wraps `npm` CLI in user scope only. It manages globally installed packages under pinned npm home paths so install, list, outdated, and info share same prefix and cache.

## Package Syntax

- `name`
- `name@version`
- scoped packages like `@types/node`
- local tarball or directory paths through `installLocal`

Examples:

```bash
rqp install npm typescript
rqp install npm eslint@9.18.0
rqp install npm @types/node
rqp test-plugin --plugin ./run.lua --preset core
```

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime And Cache Paths

- global prefix: `~/.local`
- npm cache: `~/.npm`
- XDG config/cache/data/state follow home-rooted defaults

## Notes

- wrapper manages global user packages, not project `package.json` dependencies
- commands pin `NPM_CONFIG_PREFIX` and `NPM_CONFIG_CACHE` so query and mutation paths see same state
- `outdated()` reports installed global packages with newer registry versions
