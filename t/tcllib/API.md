# Tcllib Plugin API

## Supported Actions

- `install`: install requested Tcllib release or latest release into ReqPack-managed root
- `installLocal`: install from local Tcllib source directory
- `remove`: remove current managed install
- `update`: reinstall latest or requested release into managed root
- `list`: show current managed install
- `outdated`: compare current managed install against latest remote release
- `search`: search remote Tcllib releases
- `info`: inspect remote release metadata and merge local install metadata when available

## Runtime Paths

- shared root: `~/.cache/reqpack/tcllib`
- archives: `<root>/archives`
- sources: `<root>/sources`
- active install: `<root>/current`
- manifest: `<root>/state/current.txt`

## v1 Limits

- manages Tcllib releases only
- no Teacup or Teapot operations
- no `tcllibc` accelerator build
- `installLocal` expects unpacked source tree with `installer.tcl`

## Test Command

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
