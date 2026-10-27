# reqpack-plugin-carbon

ReqPack wrapper plugin for Carbon.

Plugin manages Carbon Kubernetes packages via `carbon` CLI.

## Scope

- installs Carbon packages from Docker image refs
- removes installed Carbon packages by package name
- lists installed Carbon packages from current Kubernetes context
- shows installed package details and remote image metadata
- updates installed packages by reinstalling original source image
- returns empty results for unsupported `search()` and `outdated()`

## Files

- `metadata.json`: bundle metadata and plugin id
- `reqpack.lua`: bundle manifest
- `run.lua`: Carbon wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `.reqpack-test/core/*.lua`: hermetic plugin tests
- `API.md`: ReqPack Lua plugin API quick reference

## Usage Notes

- package install target is Docker image ref, not package name
- package remove target is installed Carbon package name
- `installLocal()` is unsupported in v1
- wrapper keeps shared ReqPack-scoped Carbon home/config/cache roots
- `search()` and `outdated()` return empty because Carbon CLI has no honest equivalent

## Running Tests

Run plugin conformance tests from plugin directory:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
