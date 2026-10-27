# hex

ReqPack Lua wrapper plugin for Hex packages in Elixir Mix projects.

## Package forms

- remote package: `plug`
- remote package with version pin: `plug@1.14.0` or ReqPack package version field
- local Mix dependency: local path passed through `installLocal()` or request `localPath`

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`
- `resolvePackage`

## Runtime and cache paths

- shared cache root: `~/.cache/reqpack/hex`
- shared `MIX_HOME`: `~/.cache/reqpack/hex/mix`
- shared `MIX_ARCHIVES`: `~/.cache/reqpack/hex/mix/archives`
- shared `HEX_HOME`: `~/.cache/reqpack/hex/hex`
- shared query project: `~/.cache/reqpack/hex/query-project`

## Behavior summary

- install/update/remove mutate `mix.exs` in target project, then run Mix dependency commands
- query actions can use explicit project dir or shared query project
- all Mix/Hex commands run with pinned noninteractive env and shared cache

## Major v1 limitations

- table parsers depend on stable English `mix` output
- private org auth is pass-through only; plugin does not manage credentials
- `mix.exs` edits are lightweight text edits, not AST rewrites

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
