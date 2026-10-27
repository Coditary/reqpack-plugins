# Metacello Plugin API

ReqPack wrapper for Pharo projects managed by `Metacello`.

## Package Forms

- remote baseline: `PharoLauncher` + `flags = { "baseline", "repository=github://pharo-project/pharo-launcher:dev/src" }`
- remote configuration: `Seaside3` + `flags = { "configuration", "repository=http://smalltalkhub.com/mc/Seaside/Seaside31/main" }`
- local FileTree install: `localPath = "/path/to/repository"` plus package `name`

## Supported Actions

- `install(context, packages)`
  Uses `pharo --headless <image> <generated-script.st>` to run `Metacello ... load`
- `installLocal(context, path)`
  Uses local `filetree://` repository against Pharo image
- `remove(context, packages)`
  Uses Pharo-side forget/remove flow and drops tracked state on success
- `update(context, packages)`
  Uses tracked repository metadata and runs refresh/load flow
- `list(context)`
  Returns tracked projects and augments from Pharo query result when available
- `outdated(context)`
  Compares tracked version with refreshed latest version when Pharo query returns both
- `search(context, prompt)`
  Repository-scoped only; requires `repository=<spec>`
- `info(context, name)`
  Returns tracked metadata and augments from Pharo query result when available

## Runtime And Cache Paths

- data root default: `~/.cache/reqpack/metacello`
- state file: `<data-root>/state/installed.json`
- script directory: `<data-root>/state`
- package cache: `<cache-root>/package-cache`

## v1 Limits

- plugin does not provision Pharo itself
- remote search needs explicit repository input because Metacello has no global searchable registry
- generic Smalltalk code unload is not guaranteed; remove is conservative
- version/outdated reporting depends on repository metadata that Metacello/Pharo query returns

## Test Command

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
