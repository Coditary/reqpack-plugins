# mill API

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Flags

- `data-root=<path>`
- `cache-root=<path>`
- `config-root=<path>`

## Behavior summary

- `install` downloads official Mill launcher script for requested or latest stable version
- `installLocal` imports local Mill launcher script into ReqPack-managed state
- `remove` deletes managed launcher script and record
- `update` upgrades installed launcher versions to latest stable release
- `list` reads ReqPack-managed launcher records
- `outdated` compares installed records to latest remote stable release
- `search` reads Mill Maven metadata and filters release versions locally
- `info` merges installed record state and remote metadata
- executed launcher probes run with shared ReqPack-scoped cache env vars
