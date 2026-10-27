# rqp-plugin-tcllib

ReqPack Lua plugin for Tcllib release installation.

Plugin wraps Tcllib source releases and installs them through bundled `installer.tcl` script into ReqPack-managed shared cache root.

## Package Syntax

- `tcllib`
- `tcllib@2.0`
- `tcllib` with separate ReqPack version field
- version shorthand like `2.0`

Examples:

```bash
rqp install tcllib tcllib
rqp install tcllib tcllib@2.0
rqp info tcllib tcllib
rqp search tcllib 1.2
```

## Supported ReqPack Paths

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Cache Behavior

- default shared root: `~/.cache/reqpack/tcllib`
- override with request flag `cache-root=/path`
- release archives cached under `archives/`
- unpacked sources cached under `sources/`
- active install lives under `current/`
- installed state stored in `state/current.txt`

## Notes

- v1 manages Tcllib releases, not arbitrary Tcl packages from wider ecosystem
- v1 uses `installer.tcl`, not `configure && make install`
- v1 does not build `tcllibc` accelerators

## Testing

Run hermetic plugin tests from plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
