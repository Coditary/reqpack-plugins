# Deft ReqPack Plugin

ReqPack plugin for Dylan packages via `deft`.

## Package forms

- `name`
- `name@latest`
- `name@1.2`
- `name@1.2.3`
- `name@branch-or-tag`

## Supported actions

- `install`
- `remove` (installed cache directories only)
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime and cache paths

- workspace packages: `<workspace>/_packages`
- global packages: `${DYLAN}/_packages`
- or `${XDG_STATE_HOME}/dylan/_packages`
- or `${HOME}/.local/state/dylan/_packages`

`search` and `info` use `deft list --all` as catalog source.

## Limitations

- `installLocal` not supported in v1
- upstream `deft` has no documented remove subcommand, so `remove` only deletes installed cache directories under `_packages`
- `info` and `search` are derived from catalog list output, not dedicated upstream subcommands

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
