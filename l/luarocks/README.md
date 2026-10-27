# reqpack-plugin-luarocks

ReqPack Lua wrapper plugin for LuaRocks `luarocks`.

Plugin uses one plugin-owned shared LuaRocks tree and shared XDG cache/config roots.
It does not install into host default `~/.luarocks` tree.

## Package Form

- `luasocket`
- `name = "luasocket", version = "3.1.0-1"`

Supported local artifact forms:

- `.rockspec`
- `.src.rock`
- `.rock`

Optional package/context flag:

- `data-root=/custom/path`

## Supported Actions

- install remote rocks into shared plugin-owned tree
- install local `.rockspec`, `.src.rock`, and `.rock` artifacts
- remove managed rocks
- update managed rocks via `luarocks install`
- list managed installed rocks
- show managed outdated rocks
- search remote LuaRocks repositories
- inspect one managed rock or best-effort remote match

## Runtime Paths

- tree root: `.reqpack-data/tree/`
- cache root: `.reqpack-data/cache/`
- config root: `.reqpack-data/config/`

## v1 Notes

- wrapper manages only plugin-owned tree
- no LuaRocks bootstrap when binary missing
- remote search/info stay thin and mostly version/repository oriented

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
