# XBPS Plugin API Notes

Short wrapper notes for this plugin.

## Behavior Summary

- `install()` uses `xbps-install -Sy`
- `installLocal()` stages into temporary local repo using symlink first and `cp` fallback, then installs from `--repository=<repo>`
- `remove()` uses `xbps-remove -Ry`
- `update()` uses `xbps-install -Suy <pkg...>` and falls back to full-system upgrade when package list is empty
- `list()` parses `xbps-query -l`
- `search()` parses `xbps-query -Rs`
- `info()` prefers installed metadata, then remote metadata
- `outdated()` parses `xbps-install -Mun`
- all cache-sensitive commands pass shared `-c <cache-dir>`

## Supported Flags

- `cache-root=/abs/path`: override shared cache root
- `repository=<url-or-path>`: append repository for remote query/install/update
- `rootdir=/abs/path`: pass `-r`
- `config=/abs/path`: pass `-C`
- `ignore-conf-repos`: pass `-i` where XBPS supports it
- `memory-sync`: pass `-M` for remote query/install metadata sync paths
- `staging`: pass `--staging`
- `download-only`: pass `-D` on install/update
- `force`: pass `-f` on install/update/local install
- `ignore-file-conflicts`: pass `-I` on install/update/local install
- `unpack-only`: pass `-U` on install/update/local install
- `recursive`: pass `-R` on remove only when requested
- `force-remove`: pass `-f` on remove
- `force-revdeps`: pass `-F` on remove
- `comparator=<op>`: build install expression with explicit comparator
- `eq`, `lt`, `lte`, `gt`, `gte`: shorthand comparator flags

Flag policy:

- install/update/query paths share one parser
- unsupported flags are ignored rather than guessed into other commands
- `remove()` stays conservative unless explicit dangerous flags are passed
- install expression policy:
  - constraint already embedded in `name` wins unchanged
  - `version=latest` omits comparator and installs by name
  - explicit `comparator=` or shorthand flag wins
  - otherwise `version` defaults to `>=`

## Returned Metadata

Plugin maps conservative XBPS fields only:

- `name`
- `packageId`
- `version`
- `latestVersion`
- `installed`
- `status`
- `summary`
- `description`
- `homepage`
- `license`
- `repository`
- `architecture`
- `dependencies`
- `categories`

Extra fields when available:

- `extraFields.state`
- `extraFields.automaticInstall`
- `extraFields.hold`
- `extraFields.repolock`

## Real Smoke Checks

- read-only checks in `SMOKE.md`
- wrapper-only smoke scripts in `.reqpack-test/extra/`

## Test Command

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
