# API

## Flags

Supported request or package flags:

- `force`
- `simple`
- `path=/custom/package/root`
- `pkg-lib=/custom/package/root`
- `artifacts=/custom/artifact/root`
- `artifact-store=/custom/artifact/root`
- `deployments=/custom/deployment/root`
- `deployment-store=/custom/deployment/root`

## Behavior Summary

- `install()` calls `kxi package install`
- `installLocal()` installs local `.kxi` artifact path
- `remove()` calls `kxi package uninstall`
- `update()` re-runs install with `--force`
- `list()` merges `kxi package list` with package-root directory scan
- `search()` searches installed packages and local artifacts
- `info()` prefers installed package details, then falls back to local artifact metadata
- `outdated()` returns `{}`

## Output Notes

- installed results include `extraFields.path` when package-root path is known
- search/info results include `extraFields.source` as `installed` or `artifact`
- artifact results use local artifact-store metadata only
