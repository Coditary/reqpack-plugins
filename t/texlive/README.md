# texlive

ReqPack wrapper for native TeX Live package management via `tlmgr`.

## Package Forms

- exact TeX Live package names like `latexmk`
- collections like `collection-fontsrecommended`
- schemes like `scheme-small`
- local TeX Live package containers for `installLocal()` via `tlmgr install --file <path>`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime And Cache

- wraps host `tlmgr`
- uses current TeX Live installation, not plugin-owned user tree
- keeps shared in-memory cache for local and remote TLPDB snapshots during one plugin process
- clears cache after successful install/remove/update/local install

## v1 Limits

- no TeX Live bootstrap/install
- exact package names only
- no persistent repository reconfiguration
- no advanced multi-repository pinning workflows

## Test

`rqp test-plugin --plugin ./run.lua --preset core`
