# x10build

ReqPack Lua wrapper for building and managing X10 from official upstream releases or local source trees.

## Package forms

- `x10`
- `app:x10`
- local source path via `installLocal()`

## Notes

- upstream source repo is `x10-lang/x10`
- upstream build entrypoint is `x10.dist`
- build command is `ant dist`
- shared cache root defaults to `~/.cache/reqpack/x10build`
- durable install root defaults to `~/.local/share/reqpack/x10build`
- only one active installed version is tracked in v1
- `info()` and `search()` expose latest GitHub release tag/name/body metadata in v1

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
