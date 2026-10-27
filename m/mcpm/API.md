# mcpm API

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Install Flags

- `force`
- `alias=<server-alias>`

## Local Install Flags

- `name=<server>`: required
- `type=stdio`: default local server type
- `type=remote`: remote HTTP/SSE server type
- `command=<command>`: stdio command, defaults to the `installLocal()` path
- `args=<args>`: stdio command arguments
- `env=<KEY=value,...>`: server environment variables
- `url=<url>`: remote server URL, defaults to the `installLocal()` path for remote servers
- `headers=<KEY=value,...>`: remote server headers
- `force`

## Update Flags

- `rebase`
- `init`
- `force`

## Behavior Summary

- `install` wraps `mcpm install`
- `installLocal` wraps `mcpm new`
- `remove` wraps `mcpm uninstall --force`
- `update` wraps `mcpm update`
- `list` reads `mcpm ls --verbose`
- `outdated` reads `mcpm update --check`
- `search` reads `mcpm search [query]`
- `info` reads `mcpm info <server>`
- all commands run with shared `MCPM_CONFIG_DIR`, `XDG_CACHE_HOME`, and `XDG_DATA_HOME` under ReqPack roots
