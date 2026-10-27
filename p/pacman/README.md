# reqpack-plugin-pacman

ReqPack Lua wrapper plugin for native Arch Linux `pacman`.

Plugin stays thin and delegates package-manager behavior to installed `pacman` binary.
Scope is official pacman repositories plus local ALPM package files.
No AUR support. No helper tools like `yay` or `paru`.

## Supported Operations

- install repo packages with `pacman -S --needed --noconfirm`
- install local package files with `pacman -U --noconfirm`
- remove packages with `pacman -R --noconfirm`
- update named packages with `pacman -S --noconfirm`
- list installed packages with `pacman -Q`
- search repositories with `pacman -Ss`
- inspect package metadata with `pacman -Si` and `pacman -Qi`
- list outdated packages with `pacman -Qu`

## Progress

Mutating pacman calls use `context.exec.run(command, { rules = ... })` when available.
This lets ReqPack surface live steps and coarse progress from typical pacman transaction output.

## Files

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: bundle manifest
- `run.lua`: pacman wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `API.md`: local ReqPack Lua plugin quick reference
- `.reqpack-test/core/*.lua`: hermetic plugin tests

## Testing

Run plugin conformance tests from repository root:

```bash
rqp test-plugin --plugin . --preset core
```

Run one case directly:

```bash
rqp test-plugin --plugin . --case ./.reqpack-test/core/info.lua
```

Run local helper checks:

```bash
lua ./.reqpack-test/local/verify-resolve-package.lua
```

## Notes

- `plugin.init()` assumes `pacman` exists natively on host
- local package file support includes `.pkg.tar.*` extensions used by ALPM packages
- security metadata uses `purlType = "alpm"` and `osvEcosystem = "Linux"`
