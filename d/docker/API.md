# ReqPack Lua Plugin API Quick Reference

Short reference for this Docker wrapper.

## Files You Usually Edit

- `metadata.json`
- `reqpack.lua`
- `run.lua`
- `scripts/install.lua`
- `scripts/remove.lua`
- `.reqpack-test/core/*.lua`
- `README.md`

## Docker Wrapper Behavior

- image refs are package ids
- missing tag normalizes to `:latest`
- Docker image store is shared cache for installed-state queries
- local state comes from `docker image ls` and `docker image inspect`
- remote state comes from `docker search` and `docker manifest inspect --verbose`
- local artifact install uses `docker load --input`

## Supported ReqPack Methods

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
function plugin.info(context, name) end
function plugin.resolvePackage(context, package) end
function plugin.getSecurityMetadata() end
```

## Testing

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
