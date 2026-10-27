# dub

ReqPack Lua wrapper for DUB.

Supports:

- shared cached packages through `package` kind
- plugin-owned synthetic D project dependencies through `dependency` kind
- local dependency path installs from folders with `dub.json` or `dub.sdl`

State and cache root:

- default: `~/.cache/reqpack/dub`
- override: `cache-root=/path`

Main paths under root:

- `dub-home/` shared `DUB_HOME`
- `project/dub.json` synthetic dependency project

Example:

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
