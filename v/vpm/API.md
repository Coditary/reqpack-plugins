# ReqPack Lua Plugin API Quick Reference

Short operator-facing reference for `vpm` wrapper.

## Files

- `metadata.json`
- `reqpack.lua`
- `run.lua`
- `scripts/install.lua`
- `scripts/remove.lua`
- `.reqpack-test/core/*.lua`

## Wrapper Behavior

- uses `v` binary for `install`, `remove`, `update`, `search`, `show`, `outdated`
- uses `VMODULES` or `~/.vmodules` as shared installed-state root
- reads local `v.mod` files for version, description, license, repo, dependencies
- treats installed module directories as local cache/state source of truth

## Notes

- `list()` walks module roots and does not require remote calls
- `info()` merges `v show <name>` output with local module metadata when installed
- `search()` uses `v search <prompt>` and enriches candidates with `v show`
- `outdated()` uses upstream `v outdated` output and then enriches ids locally
- `installLocal()` is intentionally unsupported for v1

## Testing

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
