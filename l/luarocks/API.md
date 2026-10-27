# LuaRocks Wrapper API

Short operator-facing reference for `luarocks` wrapper.

## Shared Environment

All commands run with one plugin-owned LuaRocks environment:

```text
.reqpack-data/tree
.reqpack-data/cache
.reqpack-data/config
```

Common env:

```text
XDG_CACHE_HOME=<cache>
XDG_CONFIG_HOME=<config>
luarocks --tree <tree>
```

## Actions

- `install(context, packages)`:
  - one `luarocks install` per requested rock
  - supports optional `version`
- `installLocal(context, path)`:
  - supports `.rockspec`, `.src.rock`, `.rock`
- `remove(context, packages)`:
  - uses `luarocks remove`
- `update(context, packages)`:
  - uses `luarocks install` as upgrade path
- `list(context)`:
  - parses `luarocks list --porcelain`
- `outdated(context)`:
  - parses `luarocks list --outdated --porcelain`
- `search(context, prompt)`:
  - parses `luarocks search --porcelain`
- `info(context, name)`:
  - local `luarocks show --porcelain` first
  - remote exact-name search fallback

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
