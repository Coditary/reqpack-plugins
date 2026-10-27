# reqpack-plugins

Monorepo of ReqPack Lua wrapper plugins (package managers and related tools).

## Layout

Plugins live under a **first-letter bucket** for navigation:

```text
reqpack-plugins/
  n/npm/
  n/nix/
  c/conan/
  …
```

Each plugin directory matches the [wrapper layout](https://github.com/Coditary/ReqPack/wiki/Extending-ReqPack): `run.lua`, `metadata.json`, `reqpack.lua`, `scripts/install.lua`, `scripts/remove.lua`.

## Makefile

From this directory:

```bash
make validate          # check all plugins
make list              # all plugin ids
make find Q=cargo      # filter by name
make path PLUGIN=npm   # resolve path
make test-plugin-core PLUGIN=npm   # hermetic conformance (needs `rqp` on PATH)
```

Re-import from the legacy per-repo tree:

```bash
make import            # default: ~/Dev/Coditary/plugins/reqpack
```

## Dev config

Set `registry.pluginDirectory` to this directory (absolute path). Recent ReqPack-Core builds scan single-letter buckets (`n/npm`, …) as well as flat layouts.

`make test-plugin` resolves the plugin path automatically; optional `RQ_CONFIG=/path/to/config.lua` if you need a custom config.
