# rqp-plugin-vpm

ReqPack Lua plugin for V language package management via `v` / VPM.

## Package Forms

- `author.module`
- `author.module@v0.4.0`

Examples:

```bash
rqp install vpm nedpals.args
rqp install vpm nedpals.args@0.10.0
rqp info vpm nedpals.args
```

## Supported Actions

- `install`
- `installLocal` (unsupported, fails clearly)
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`
- `resolvePackage`

## Runtime And Cache Paths

- shared module root comes from `VMODULES`
- fallback root is `~/.vmodules`
- plugin treats first `VMODULES` path as canonical writable root
- installed state and local metadata come from module directories and `v.mod`

## Limitations

- local artifact install not supported in v1
- `outdated` usually reports package ids but not latest versions, so `latestVersion` may be empty
- plugin wraps `v` subcommands, not a separate `vpm` binary

## Testing

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
