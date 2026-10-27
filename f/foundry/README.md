# Foundry ReqPack Plugin

ReqPack Lua wrapper for Foundry `forge` dependency management in Solidity projects.

## Package forms

- GitHub shorthand like `foundry-rs/forge-std`
- raw git URLs like `https://github.com/OpenZeppelin/openzeppelin-contracts`
- optional alias form via flags: `alias=<folder>`

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `search`
- `info`
- `outdated` returns empty list in v1

## Runtime and cache paths

- project libs: usually `lib/`
- project cache: usually `cache/`
- global Foundry home: `~/.foundry`
- global Foundry cache: `~/.foundry/cache`

## Major v1 limitations

- wraps `forge` dependency workflow, not build/test/deploy commands
- `search()` is local-first plus direct dependency spec fallback because Foundry has no native remote search
- `installLocal()` is unsupported
- `outdated()` is intentionally empty because Foundry has no reliable per-package outdated report

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
