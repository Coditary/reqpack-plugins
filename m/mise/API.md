# mise API

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Flags

- `force`
- `jobs=<n>`
- `raw`
- `system`
- `minimum-release-age=<value>`

## Behavior summary

- `install` wraps `mise install`
- `remove` wraps `mise uninstall`
- `update` resolves outdated versions and reinstalls latest matching version
- `list` reads `mise ls --installed --json`
- `outdated` reads `mise outdated --json --inactive`
- `search` reads `mise registry --json` and filters locally
- `info` merges installed state, registry metadata, and remote version data
- all commands run with shared `MISE_DATA_DIR`, `MISE_CACHE_DIR`, `MISE_CONFIG_DIR`, and `MISE_STATE_DIR` under ReqPack roots
