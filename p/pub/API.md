# ReqPack Lua Plugin API Quick Reference

Short reference for pub wrapper.

## Files

- `metadata.json`: bundle metadata
- `reqpack.lua`: ReqPack dependency declaration
- `run.lua`: wrapper implementation
- `scripts/install.lua` and `scripts/remove.lua`: required hook stubs
- `.reqpack-test/core/*.lua`: hermetic tests

## Pub Wrapper Behavior

- mutating actions use `dart pub global`
- `installLocal()` uses `dart pub global activate --source path`
- `list()` parses `dart pub global list`
- `search()` uses cached `https://pub.dev/api/package-name-completion-data`
- `info()` and `outdated()` use `https://pub.dev/api/packages/<name>` plus score/publisher endpoints
- all commands share `PUB_CACHE=~/.cache/reqpack/pub/pub-cache` unless `cache-root=...` overrides it

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
```

## Testing

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
