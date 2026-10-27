# Boss API

## Flags

- `global`
- `no-save`
- `strict`
- `compiler=<value>`
- `platform=<value>`
- `cache-root=<path>`

Flags may be provided at request level or per package.

## Behavior summary

- `install`: runs `boss install` per package
- `installLocal`: runs `boss install` inside target directory containing `boss.json`
- `remove`: runs `boss uninstall` per package
- `update`: runs `boss update [packages...]`
- `list`: reads `boss.json` and `boss-lock.json`
- `outdated`: compares lock versions with cached Boss repo info under `cache/info`
- `search`: searches current manifest and cached repo names only
- `info`: combines manifest/lock data with cached repo info when available
