# zplug

ReqPack wrapper for `zplug`.

## Package Forms

- `user/repo`
- `plugins/git`
- `themes/example`
- local path like `~/.zsh` with `from=local`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search` for ReqPack-managed registrations only
- `info`

## Runtime And Cache Paths

- `ZPLUG_HOME`: default `~/.zplug`
- `ZPLUG_CACHE_DIR`: default `~/.zplug/cache`
- `ZPLUG_LOADFILE`: default `~/.zplug/packages.zsh`

## v1 Limits

- `search()` only searches packages registered in ReqPack-managed `ZPLUG_LOADFILE`
- wrapper does not import package declarations from user `.zshrc`
- shell commands run through `zsh -lc`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
