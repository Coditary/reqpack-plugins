# uv Plugin API

## Behavior

- `install(packages)` runs `uv tool install` once per package
- `installLocal(path)` runs `uv tool install <path>`
- `remove(packages)` runs `uv tool uninstall`
- `update(packages)` runs `uv tool upgrade`
- `list()` reads installed tools from shared tool dir receipts and metadata
- `outdated()` uses `uv tool list --outdated -v` and enriches with PyPI latest versions
- `search(prompt)` queries PyPI search HTML
- `info(name)` queries `https://pypi.org/pypi/<name>/json`

## Supported Flags

- `cache-root=<path>`
- `editable`
- `force`
- `refresh`
- `with=<requirement>`
- `with-executables-from=<package>`
- `python=<request>`
- `prerelease=<mode>`
- `all` for `update` with no packages

## Output Enrichment

Returned package items may include:

- `extraFields.requirements`
- `extraFields.entrypoints`
- `extraFields.toolPath`
- `extraFields.binDir`
- `extraFields.cacheDir`
- `extraFields.python`
- `extraFields.source`

## v1 Limits

- no project-local `uv pip` or lockfile management
- no authenticated private-index workflow helpers
- `search()` depends on current PyPI search HTML structure
