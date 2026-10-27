# EUPM Plugin API

Supported ReqPack actions:

- `install(packages)` -> `eupm install <name>[@version]`
- `installLocal(path)` -> `eupm install <path>`
- `remove(packages)` -> `eupm remove <name>`
- `update(packages)` -> `eupm update <name>`
- `list()` -> `eupm list`
- `outdated()` -> returns empty list in v1
- `search(prompt)` -> `eupm search <prompt>`
- `info(name)` -> `eupm info <name>`

Returned metadata:

- common fields when detectable: `name`, `packageId`, `version`, `latestVersion`, `installed`, `status`, `summary`, `description`, `homepage`, `license`
- package type defaults to `library`
- `extraFields.rawHeader` may be set when info parsing sees unmatched header text

Runtime details:

- operations run through native `eupm`
- wrapper reuses native package state and query behavior
- no plugin-owned cache is created in v1
- parser accepts several likely plain-text forms such as `name version`, `name - version`, and `Key: Value`
- optional probe mode can detect alternate upstream verbs from help output

Probe controls:

- env: `REQPACK_EUPM_PROBE=1`
- flag: `probe`

Probe candidates:

- `eupm --help`
- `eupm help`
- `eupm -h`

Diagnostic helper:

- `diagnoseEupm(context)` -> returns table with:
  - `binary`
  - `binaryFound`
  - `probeEnabled`
  - `probeAttempted`
  - `helpCommands`
  - `verbs.install/remove/update/list/search/info`

Verification note:

- official public Euphoria releases and current upstream source tree did not expose a shipped `eupm` binary during verification
- command contract therefore remains best-effort until real upstream `eupm` becomes available

Security metadata summary:

- role: `package-manager`
- capabilities: `exec`
- privilege: `none`
- ecosystem scope: `euphoria`

Test command:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
