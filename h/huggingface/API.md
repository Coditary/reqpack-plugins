# ReqPack Lua Plugin API Quick Reference

Short reference for this wrapper.
Source of truth is ReqPack wiki page `Extending-Writing-Lua-Plugins` from this project.

## Files You Usually Edit

- `metadata.json`: plugin id and bundle metadata
- `reqpack.lua`: bundle manifest with `apiVersion` and `depends`
- `run.lua`: main wrapper implementation
- `scripts/install.lua` and `scripts/remove.lua`: required bundle hook stubs
- `.reqpack-test/core/*.lua`: hermetic plugin tests
- `README.md`: quickstart for people opening bundle first

## Hugging Face Wrapper Behavior

- dependency install declared in `reqpack.lua` as `depends = { "nix:huggingface-hub" }`
- `plugin.getRequirements()` stays empty; wrapper does not call `nix` directly
- `install()` and `update()` run Hugging Face CLI, then adopt downloaded files into `~/.local/share/aicache`
- adopted cache layout includes:
  - `blobs/sha256/<prefix>/<digest>`
  - `artifacts/<artifact-id>/{manifest.json,files.json,source.json}`
  - `views/by-kind/...`, `views/by-format/...`, `views/by-source/...`
- `list()` prefers AICache `views/by-source/huggingface/**/current.json`, then falls back to `hf cache ls --format json`
- `info()` prefers AICache artifact metadata, then falls back to `hf models|datasets|spaces info ... --format json`
- `remove()` deletes AICache artifact metadata/views and prunes unreferenced adopted blobs; it does not manage original Hugging Face cache ownership
- `outdated()` remains SHA-based against Hugging Face remote metadata

## Required Methods

ReqPack expects these methods on `plugin`:

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
function plugin.search(context, prompt) end
function plugin.info(context, packageName) end
```

## Testing

```bash
rqp test-plugin --plugin . --preset core
```

Current core preset covers CLI behavior and wrapper flows.
Real AICache ingest/query behavior is currently verified with targeted smoke runs because plugin test harness only fakes command execution and cannot seed on-disk cache fixtures yet.
