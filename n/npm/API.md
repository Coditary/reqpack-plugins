# ReqPack Lua Plugin API Quick Reference

Short operator-facing reference for `npm` wrapper.

## Files

- `metadata.json`
- `reqpack.lua`
- `run.lua`
- `scripts/install.lua`
- `scripts/remove.lua`
- `.reqpack-test/core/*.lua`

## npm Wrapper Behavior

- wraps global user-scoped npm package management only
- all commands run with pinned env for shared prefix and cache
- `install()` uses `npm install -g`
- `installLocal()` uses `npm install -g <path>`
- `remove()` uses `npm uninstall -g`
- `update()` uses `npm update -g`
- `list()` uses `npm ls -g --depth=0 --json`
- `outdated()` uses `npm outdated -g --depth=0 --json`
- `search()` uses `npm search --json`
- `info()` uses `npm view --json`

## Testing

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
