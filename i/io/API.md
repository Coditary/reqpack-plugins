# API

Supported actions:

- `install`: `eerie install <uri>`
- `installLocal`: `eerie install <path>`
- `remove`: `eerie remove <name>`
- `update`: `eerie update <name>` or `eerie pkg:updateAll`
- `list`: read installed state from `EERIEDIR/config.json` and package manifests
- `search`: best-effort direct-target or installed-package search
- `info`: installed-package metadata or synthetic direct-target info
- `outdated`: returns empty list in v1

Supported request hints:

- package `source`, `url`, or `uri`
- package or request flag `env=<name>`
- request flags `data-root=...`, `cache-root=...`, `config-root=...`

Notes:

- plugin id is `io`, but actual package manager is `eerie`
- plain `owner/repo` search or install inputs normalize to `https://github.com/owner/repo.git`
- Eerie has no central remote catalog, so search is intentionally limited
