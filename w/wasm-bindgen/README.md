# wasm-bindgen ReqPack Plugin

Thin ReqPack wrapper for `wasm-bindgen-cli`.

## Package Forms

- remote tool: `wasm-bindgen-cli`
- remote tool alias: `wasm-bindgen`
- generated cache entry: `generated:<cache-key>`
- local artifact for `installLocal()`: `path/to/module.wasm`

## Supported Actions

- `install()` installs `wasm-bindgen-cli` through Cargo
- `remove()` removes installed tool or cached generated entry
- `update()` upgrades installed tool through Cargo
- `list()` lists installed tool plus cached local generation outputs
- `search()` matches known aliases for `wasm-bindgen-cli`
- `info()` returns tool metadata or cached generation manifest
- `installLocal()` runs `wasm-bindgen` on local `.wasm`
- `outdated()` returns empty list in v1

## Runtime And Cache Paths

- Cargo tool state: user Cargo home, typically `~/.cargo/`
- plugin cache root: ReqPack data root if available, else `~/.cache/reqpack/wasm-bindgen`
- generated outputs: `<cache-root>/generated/<cache-key>/out/`
- cache manifests: `<cache-root>/generated/<cache-key>/manifest.json`

## Important v1 Limits

- manages one upstream tool: `wasm-bindgen-cli`
- no `wasm-pack` integration
- no automatic remote outdated detection
- local generation only accepts `.wasm`
- `remove()` deletes generated output only for cache-managed outputs

## Useful Flags For `installLocal()`

- `target=web|bundler|nodejs|no-modules|deno|experimental-nodejs-module`
- `out-dir=/custom/path`
- `typescript=false`
- `debug=true`
- `browser=true`
- `keep-debug=true`
- `keep-lld-exports=true`
- `omit-default-module-path=true`
- `omit-imports=true`
- `split-linked-modules=true`
- `no-demangle=true`
- `no-modules-global=MyBindings`
- `reset-state=true`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
