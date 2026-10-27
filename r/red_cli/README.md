# red_cli

ReqPack Lua wrapper for local `red-cli` projects.

## Package forms

- `/abs/path/to/project`
- `/abs/path/to/red.config.json`
- tracked project name after first install

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime and cache paths

- shared state root: `~/.cache/reqpack/red_cli`
- tracked projects: `~/.cache/reqpack/red_cli/tracked-projects.txt`

## v1 limitations

- wraps local project workflow, not remote package registry
- `search()` searches tracked projects only
- `outdated()` always returns empty list
- `remove()` derives install targets from `red.config.json`; no upstream uninstall command exists
- game auto-detection is not implemented; use `REDCLI_GAME` or `game` in config

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
