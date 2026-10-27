# mcpm

ReqPack Lua wrapper for `mcpm` MCP server management with one shared ReqPack-scoped config, cache, and data root.

## Package Forms

- `github`
- `filesystem`
- `sqlite` with `flags = { "alias=db" }`
- local stdio server via `installLocal()` and flags like `name=myserver`, `command=python -m server`, `args=--port 8080`
- remote server via `installLocal()` and flags like `name=remote-api`, `type=remote`, `url=https://example.com/mcp/`

## Supported Actions

- install registry MCP servers
- install custom stdio or remote MCP servers
- remove installed servers
- update one or all installed servers
- list installed servers
- check outdated servers with `mcpm update --check`
- search the MCPM registry
- inspect one registry or installed server

## Runtime and Cache Paths

- config root: `~/.config/reqpack/mcpm/config`
- cache root: `~/.cache/reqpack/mcpm/cache`
- data root: `~/.local/share/reqpack/mcpm/data`

All MCPM commands run with `MCPM_NON_INTERACTIVE=true`, `MCPM_FORCE=true`, and `MCPM_JSON_OUTPUT=true`.

## v1 Limitations

- profile, client, run, share, usage, doctor, and config commands are not exposed as ReqPack package actions
- `outdated()` depends on MCPM's `update --check` JSON output
- MCP server runtime secrets remain MCPM/server concerns and are only passed through when requested via local install flags

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
