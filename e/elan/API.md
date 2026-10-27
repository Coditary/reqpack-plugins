# elan Plugin API

Supported ReqPack actions:

- `install(packages)` -> `elan toolchain install <toolchain>`
- `installLocal(path)` -> `elan toolchain link <name> <path>`
- `remove(packages)` -> `elan toolchain uninstall <toolchain>`
- `update(packages)` -> `elan toolchain install <toolchain>`
- `list()` -> `elan toolchain list` plus `elan show` and `elan dump-state --no-net`
- `outdated()` -> conservative stale detection from native state, often empty in v1
- `search(prompt)` -> local/native candidates plus standard channels
- `info(name)` -> installed/default/active summary for one toolchain

Returned metadata:

- common fields: `name`, `packageId`, `version`, `installed`, `status`, `summary`, `description`, `installPath`
- `latestVersion` only when honestly known
- `packageType` defaults to `toolchain`
- `extraFields` may include `default`, `active`, `activeReason`, `linkedPath`, `elanHome`, `overridePath`, `rawLine`

Request extras:

- `extraFields.setDefault = true` sets installed toolchain as default
- `extraFields.overridePath = "/path"` sets override after install or update
- `extraFields.linkName = "lean-dev"` names local linked toolchain for `installLocal()`

Runtime details:

- wrapper reuses native `ELAN_HOME` shared state
- no plugin-owned cache is created in v1
- `dump-state --no-net` JSON is preferred when available; text parsing is fallback
- local linked toolchains are detected from `elan show` annotations

Security metadata summary:

- role: `package-manager`
- capabilities: `exec`
- privilege: `none`
- ecosystem scope: `lean`
- write scope: `~/.elan`

Test command:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
