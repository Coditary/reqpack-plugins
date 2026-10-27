# API

## Flags

- `branch=<name>`
- `tag=<name>`
- `commit=<sha>`
- `rtp=<subdir>`
- `as=<alias>`
- `dir=<path>`
- `do=<command>`
- `on=<cmd[,cmd2]>`
- `for=<ft[,ft2]>`
- `frozen`
- `data-root=<path>`
- `cache-root=<path>`
- `config-root=<path>`

## Behavior Summary

- remote installs generate isolated Vim config and run `PlugInstall --sync`
- updates run `PlugUpdate --sync`
- removal updates manifest and runs `PlugClean!` only for ReqPack-owned managed dirs
- outdated/info use `git ls-remote --symref` for remote inspection when possible
- local installs register existing plugin directories without copying them into clone cache

## Example

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
