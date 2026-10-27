# reqpack-plugin-spm API

## Supported Actions

- `install(packages)` -> `spm install --json <specifier>`
- `installLocal(path)` -> `spm install --json --no-link <path>`
- `remove(packages)` -> `spm uninstall --json <name>`
- `update(packages)` -> `spm update --json [name...]`
- `list()` -> `spm list --json`
- `outdated()` -> `spm list --json` + `spm info --json`
- `search(prompt)` -> `spm search <prompt> --json`
- `info(name)` -> `spm info <name> --json`

## Returned Metadata

Items expose `extraFields` when known:

- `spm.storeRoot`
- `spm.cacheRoot`
- `spm.projectManifest`
- `spm.projectLockfile`
- `spm.storePath`
- `spm.range`
- `spm.author`
- `spm.trustTier`

## Limitations

- no persona/publish/login wrapping in v1
- no upstream global outdated command; outdated is derived from project list + registry info
- local path install only succeeds when upstream JSON reports observable installed skill state

## Test Command

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
