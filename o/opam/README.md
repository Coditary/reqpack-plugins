# opam

ReqPack wrapper for `opam` packages and local opam sources.

## Package forms

- package name: `dune`
- exact version: `dune` with `version = "3.17.2"`
- raw constraint: `ppxlib` with `flags = { "constraint=>=0.35.0" }`
- local path: `installLocal()` with directory or `.opam` file path

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

- default opam root: `~/.opam`
- shared download cache lives under chosen opam root, typically `~/.opam/download-cache/`
- optional ReqPack-managed root: `data-root=<path>` -> `<path>/opam-root`

## v1 limitations

- does not bootstrap `opam`
- does not create opam roots or switches automatically
- expects selected root/switch to already exist for switch-scoped actions

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
