# rqp-plugin-xbps

ReqPack Lua wrapper plugin for XBPS.

Plugin wraps native Void Linux tools:

- `xbps-install`
- `xbps-remove`
- `xbps-query`
- `xbps-rindex`

## Supported ReqPack Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`
- `resolvePackage`

## Package Forms

- `bash`
- `bash>=5.2`
- `bash` with `version="5.2_1"` becomes `bash>=5.2_1` by default
- `bash` with `version="5.2_1"` and `flags={"comparator=="}` becomes `bash=5.2_1`
- local artifact path: `/path/to/pkg-1.0_1.x86_64.xbps`

## Supported Request Flags

- `cache-root=/abs/path`: override shared ReqPack cache root
- `repository=<url-or-path>`: add one or more XBPS repositories for remote queries/install/update
- `rootdir=/abs/path`: target alternate XBPS root
- `config=/abs/path`: use alternate XBPS config dir
- `ignore-conf-repos`: ignore repos from XBPS config and only use explicit `repository=` flags
- `memory-sync`: force fresh in-memory remote metadata fetch where XBPS supports it
- `staging`: enable staged packages for remote queries/install/update
- `download-only`: install/update downloads packages only
- `force`: pass XBPS force install/update behavior
- `ignore-file-conflicts`: ignore install/update file conflicts
- `unpack-only`: unpack without configure during install/update
- `recursive`: recursive remove, only when explicitly requested
- `force-remove`: force file removal on `remove()`
- `force-revdeps`: force remove even with reverse dependencies
- `comparator=<op>`: version comparator for install expression, one of `=`, `<`, `<=`, `>`, `>=`, `==`
- shorthand comparator flags: `eq`, `lt`, `lte`, `gt`, `gte`

Repeated `repository=` flags are supported.
If request has `version` but no comparator flag, plugin defaults to `>=` for XBPS install expressions.

## Runtime And Cache Paths

- shared cache root: `~/.cache/reqpack/xbps`
- XBPS cache dir: `~/.cache/reqpack/xbps/cache`
- temp local repos: `~/.cache/reqpack/xbps/local-repos`

All query and install/update flows reuse same XBPS cache dir so repository metadata and downloaded packages stay shared.

## Notes

- plugin does not bootstrap XBPS tools
- mutating commands assume caller handles any required privilege escalation outside plugin
- `installLocal()` stages local `.xbps` into temporary repository with symlink first and `cp` fallback, then installs through native XBPS flow
- first version installs named packages by package expression when already provided; otherwise by package name
- `remove()` is conservative by default and does not add recursive removal unless `recursive` flag is set
- `update()` with empty package list now performs full-system XBPS upgrade

## Command Mapping

- `install` -> `xbps-install -S -y ...`
- `install --local <file.xbps>` -> temp local repo + `xbps-rindex -a` + `xbps-install --repository=<repo>`
- `remove` -> `xbps-remove -y ...`
- `update <pkg...>` -> `xbps-install -S -u -y ... <pkg...>`
- `update` with no package list -> full-system `xbps-install -S -u -y`
- `list` -> `xbps-query -l`
- `search` -> `xbps-query -R -s <prompt>`
- `info` -> installed property lookups first, then repository property lookups
- `outdated` -> `xbps-install -u -n -M ...`

## Examples

```bash
rqp search xbps ripgrep
rqp info xbps hello
rqp install xbps ripgrep
rqp install xbps hello --flags repository=https://repo-default.voidlinux.org/current
rqp install xbps --local /tmp/demo-1.0_1.x86_64.xbps
rqp update xbps
rqp remove xbps hello --flags recursive
```

## Testing

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```

Real-host smoke workflow:

```bash
./SMOKE.md
```
