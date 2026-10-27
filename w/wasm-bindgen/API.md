# API

## Remote Tool

Canonical package:

- `wasm-bindgen-cli`

Accepted aliases:

- `wasm-bindgen`
- `wasm-bindgen-cli`

## `install(context, packages)`

- command: `cargo install --color never [--version X] wasm-bindgen-cli`

## `update(context, packages)`

- command: `cargo install --color never --force [--version X] wasm-bindgen-cli`
- empty package list updates installed managed tool when present

## `remove(context, packages)`

- tool command: `cargo uninstall wasm-bindgen-cli --color never`
- generated cache entries remove stored manifest and cache-managed output

## `list(context)`

Returns:

- installed tool item when Cargo reports `wasm-bindgen-cli`
- cached generated entries from manifest files under plugin cache root

## `search(context, prompt)`

Returns one known package when prompt matches:

- `wasm`
- `bindgen`
- `wasm-bindgen`
- `wasm-bindgen-cli`

## `info(context, name)`

- tool alias => Cargo-backed metadata for `wasm-bindgen-cli`
- `generated:<cache-key>` => cached manifest entry

## `installLocal(context, path)`

Supported local target:

- `.wasm`

Base command:

```sh
wasm-bindgen <path> --out-dir <dir> --target <target>
```

Optional flags map to upstream CLI flags:

- `target=...`
- `out-dir=...`
- `typescript=false` => `--no-typescript`
- `debug=true` => `--debug`
- `browser=true` => `--browser`
- `keep-debug=true` => `--keep-debug`
- `keep-lld-exports=true` => `--keep-lld-exports`
- `omit-default-module-path=true` => `--omit-default-module-path`
- `omit-imports=true` => `--omit-imports`
- `split-linked-modules=true` => `--split-linked-modules`
- `no-demangle=true` => `--no-demangle`
- `no-modules-global=<name>` => `--no-modules-global <name>`
- `reset-state=true` => `--experimental-reset-state-function`

## `outdated(context)`

- returns `[]` in v1
