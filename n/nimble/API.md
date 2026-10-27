# Nimble ReqPack API Notes

## Supported Actions

- `install`: `nimble --accept --noColor install <selector>`
- `installLocal`: same command with local directory or `.nimble` path
- `remove`: `nimble --accept --noColor uninstall <selector>`
- `update`: re-runs `install` for requested selectors
- `list`: `nimble --noColor list -i`
- `search`: `nimble --accept --noColor refresh`, then `nimble --noColor search <prompt>`
- `info`: installed-first lookup, then exact remote search fallback
- `outdated`: returns `{}`

## Package Fields

Installed rows expose best-effort:

- `name`
- `packageId`
- `version`
- `installed = true`
- `status = "installed"`

Search/info rows expose best-effort:

- `name`
- `packageId`
- `summary`
- `description`
- `homepage`
- `repository`
- `license`
- `extraFields.tags`

## Local Install Targets

- package directory
- `.nimble` file

Anything else fails explicitly.

## Shared Cache

Plugin intentionally reuses Nimble shared cache under `~/.nimble`.
This keeps install state, downloaded package content, binaries, and managed Nim toolchains in one place.
