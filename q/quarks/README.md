# quarks

ReqPack Lua wrapper plugin for SuperCollider Quarks via `sclang`.

## Package Forms

- `MathLib`
- `https://github.com/supercollider-quarks/MathLib.git`
- local path via `installLocal()`, e.g. `~/supercollider/quarks/my-quark`
- optional git refspec in request `version`, e.g. `tags/1.0.0` or commit SHA

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Shared Cache And Runtime Paths

- plugin root: `data-root/quarks` when `data-root=...` flag passed
- fallback root: `~/.local/share/reqpack/quarks` through ReqPack `dataRoot` or `.reqpack-data/quarks` in tests
- isolated SuperCollider home: `<root>/home`
- isolated `sclang` config: `<root>/config/sclang_conf.yaml`
- installed snapshot: `<root>/state/installed.tsv`
- directory cache: `<root>/cache/directory.tsv`
- generated driver scripts: `<root>/runtime/scripts/*.scd`

## Major v1 Limitations

- requires `sclang` on PATH
- install/remove/update mutate Quarks state, but SuperCollider class-library recompile still remains user/runtime concern
- `outdated()` only reports git-backed installs with resolvable upstream tracking refs
- search/info for remote-only quarks depend on Quarks directory fetch succeeding once or cached directory snapshot existing

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
