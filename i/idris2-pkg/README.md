# idris2-pkg

ReqPack wrapper for Idris2 package management through upstream `pack` CLI from `stefan-hoeck/idris2-pack`.

## Package forms

- remote Idris2 library name: `hedgehog`
- local Idris project file: `/path/to/project.ipkg`

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

- shared plugin home: `~/.cache/reqpack/idris2-pkg/home`
- pack config: `~/.cache/reqpack/idris2-pkg/home/.config/pack`
- pack cache: `~/.cache/reqpack/idris2-pkg/home/.cache/pack`
- pack state: `~/.cache/reqpack/idris2-pkg/home/.local/state/pack`
- ReqPack install manifest: `~/.cache/reqpack/idris2-pkg/installed.tsv`

## v1 limitations

- wraps upstream `pack` binary, not separate `idris2-pkg` executable
- `install()` and `remove()` target libraries, not `install-app` / `remove-app`
- `installLocal()` supports `.ipkg` only and installs dependencies for local project
- `outdated()` returns empty list in v1
- installed package listing comes from ReqPack-managed manifest updated by this plugin

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
