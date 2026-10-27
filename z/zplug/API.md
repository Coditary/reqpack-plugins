# zplug API

## Request Flags

- `zplug-home=/abs/path`
- `cache-root=/abs/path`
- `loadfile=/abs/path`
- zplug tag flags via `key=value` or boolean token:
  - `as=plugin|command|theme`
  - `from=github|gitlab|bitbucket|gh-r|gist|oh-my-zsh|prezto|local`
  - `use=...`
  - `at=...`
  - `rename-to=...`
  - `if=...`
  - `hook-build=...`
  - `hook-load=...`
  - `ignore=...`
  - `on=...`
  - `depth=...`
  - `defer=...`
  - `frozen`
  - `lazy`

## Behavior

- `install()` writes package registration into `ZPLUG_LOADFILE` before calling `zplug install`
- `installLocal()` auto-adds `from:local` when missing
- `remove()` runs `zplug clean --force <package>` then rewrites `ZPLUG_LOADFILE`
- `list()` returns installed packages detected by `zplug list`
- `outdated()` matches `zplug status` output against registered packages
- `info()` merges `zplug info` output with registration metadata
