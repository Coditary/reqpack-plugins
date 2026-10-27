# ReqPack Lua Plugin API Quick Reference

Short reference for `sdkman` wrapper bundle.

## Files

- `metadata.json`
- `reqpack.lua`
- `run.lua`
- `scripts/install.lua`
- `scripts/remove.lua`
- `.reqpack-test/core/*.lua`

## Wrapper Behavior

- sources `~/.sdkman/bin/sdkman-init.sh` before `sdk` commands
- treats installed candidate versions as package records
- reads installed inventory from `~/.sdkman/candidates`
- reads candidate search catalog from `~/.sdkman/var/candidates`
- resolves latest/default versions through sourced SDKMAN runtime
- keeps shared cache rooted in `~/.sdkman`

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
