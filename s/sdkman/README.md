# rqp-plugin-sdkman

ReqPack Lua plugin for `sdkman`.

Plugin wraps SDKMAN runtime and manages installed candidate versions as ReqPack packages.

## Package Forms

- `name=<candidate>` and `version=<exact-version>`
- `name=<candidate>` with no version to install latest stable default

Examples:

```bash
rqp install sdkman groovy@4.0.28
rqp install sdkman java
```

## Supported Actions

- `install`
- `installLocal` (unsupported, fails clearly)
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`
- `resolvePackage`

## Shared Cache And Runtime Paths

- `~/.sdkman/bin/sdkman-init.sh`
- `~/.sdkman/candidates`
- `~/.sdkman/tmp`
- `~/.sdkman/var/candidates`
- `~/.sdkman/var/metadata`

Plugin does not add its own cache. It uses shared SDKMAN state only.

## v1 Notes

- package identity is candidate version, not candidate name alone
- list/info use shared SDKMAN cache under `~/.sdkman/candidates`
- search uses SDKMAN candidate cache from `~/.sdkman/var/candidates`
- `installLocal()` is unsupported because SDKMAN local installs need candidate name plus version label
- installs do not change SDKMAN default symlink in v1

## Testing

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
