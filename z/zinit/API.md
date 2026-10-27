# ReqPack Lua Plugin API Quick Reference

Short reference for `zinit` wrapper bundle.

## Files

- `metadata.json`
- `reqpack.lua`
- `run.lua`
- `scripts/install.lua`
- `scripts/remove.lua`
- `.reqpack-test/core/*.lua`

## Wrapper Behavior

- runs `zinit` through `zsh -lc` after sourcing managed `zinit.zsh`
- bootstraps managed `zinit.git` clone on install paths only
- stores managed package state in `packages.tsv`
- regenerates `packages.zsh` from manifest after mutating actions
- keeps shared Zinit home under ReqPack-managed data root

## Required Methods

```lua
function plugin.getName() end
function plugin.getVersion() end
function plugin.getRequirements() end
function plugin.getCategories() end
function plugin.getMissingPackages(packages) end
function plugin.install(context, packages) end
function plugin.installLocal(context, path) end
function plugin.remove(context, packages) end
function plugin.update(context, packages) end
function plugin.list(context) end
function plugin.outdated(context) end
function plugin.search(context, prompt) end
function plugin.info(context, packageName) end
function plugin.resolvePackage(context, package) end
function plugin.shutdown() end
```

## Testing

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
