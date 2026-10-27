# mise

ReqPack Lua wrapper for `mise` tool-version installs with one shared ReqPack-scoped cache/state root.

## Package forms

- `node`
- `node@20`
- `python@3.12.4`
- `bun@latest`

## Supported actions

- install exact or fuzzy tool versions
- remove installed tool versions
- update outdated installed tool versions
- list installed tool versions
- search available tools from `mise registry`
- inspect installed or remote tool metadata

## Runtime and cache paths

- data root: `~/.local/share/reqpack/mise/data`
- cache root: `~/.cache/reqpack/mise/cache`
- config root: `~/.config/reqpack/mise/config`
- global config file: `~/.config/reqpack/mise/config/config.toml`

## v1 limitations

- `installLocal()` unsupported
- wrapper does not edit project `mise.toml` files
- search covers tools, not concrete versions
- local config activation/shims outside plugin scope

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
