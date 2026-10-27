# texlive API

## Flags

- `repository=<url-or-path>`: override repository for current command
- `force`
- `reinstall`
- `with-doc`
- `with-src`
- `no-depends`
- `no-depends-at-all`

## Behavior

- `install()` runs per package for deterministic failures
- `update()` runs `tlmgr update --all` with no package list
- `update()` groups package updates by repository and flag set
- `list()` uses installed-package CSV output first, then falls back to local TLPDB snapshot
- `info()` prefers `tlmgr info --json`, then falls back to cached local/remote TLPDB lookups
- `outdated()` prefers machine-readable `update --list`, then falls back to local/remote snapshot comparison

## Security Model

- native `tlmgr` may write into host TeX Live trees
- metadata declares conservative write/network scope
