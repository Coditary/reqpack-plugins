# rqp-plugin-fan

ReqPack Lua wrapper plugin for Fantom pods.

Plugin id is `fan`.
Runtime/package manager binary used by wrapper is `fanr`.

## Package Forms

- `web`
- `web@1.0.79`
- local `.pod` archive path for `installLocal`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`
- `resolvePackage`

## Behavior

- wraps real upstream package manager `fanr`, not `fan` runtime verbs
- uses shared Fantom environment pod directory from `fanr config`
- no plugin-owned installed-state cache in v1
- `search()` and `info()` parse human-readable `fanr query` output
- `update()` uses `fanr install` because upstream install already upgrades existing pods
- `installLocal()` copies local `.pod` archive into shared `env.work/lib/fan/`

## Runtime And Cache Paths

- shared Fantom home root: `env.home` from `fanr config`
- shared Fantom work root: `env.work` from `fanr config`
- installed pod directory: `env.work/lib/fan/`
- remote repo URI: `repo` from `fanr config` or request flag `repo=<uri>`

## Major v1 Limitations

- native `fanr` output is text, so parsing stays conservative
- `installLocal()` supports local `.pod` archives only
- no native upstream JSON output, so metadata richness depends on summary/version lines
- no plugin-specific cache because upstream env and repo config already provide shared state

## Testing

Run from plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
