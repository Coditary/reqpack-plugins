# gleam

ReqPack Lua wrapper for Gleam project dependency management.

## Package forms

- `package`
- `package@version`
- request object with `name`, optional `version`
- install flag: `dev`

## Supported actions

- `install`
- `installLocal` (returns unsupported error)
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime paths

- project manifest: `./gleam.toml`
- lock manifest: `./manifest.toml`
- shared cache root noted for ReqPack metadata: `~/.cache/reqpack/gleam`

## Notes

- mutation and local dependency queries require project root with `gleam.toml`
- remote `search` and fallback `info` use Hex public JSON API through `curl`
- `installLocal()` not exposed by Gleam CLI; use manual path dependency in `gleam.toml`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
