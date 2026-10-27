# Opa Plugin API

Supported ReqPack actions:

- `install(packages)` -> native `opa` build per local target
- `installLocal(path)` -> resolve local target then native `opa` build
- `remove(packages)` -> remove generated outputs only
- `update(packages)` -> rebuild known local targets
- `list()` -> list known local built targets from inventory/filesystem
- `outdated()` -> returns empty list in v1
- `search(prompt)` -> local search over known targets
- `info(name)` -> local target summary

Accepted target forms:

- `.opa`
- `.opack`
- `.conf`
- `.opx`
- directory containing exactly one supported target after resolution rules

Supported flags:

- `compile` -> `opa -c <target>`
- `link` -> `opa -l <target>`
- `autocompile` -> `opa --autocompile <target>`
- `api` -> append `--api`
- `warn-error=<class>` -> append `--warn-error <class>`

Returned metadata:

- common fields when detectable: `name`, `packageId`, `installed`, `status`, `summary`, `description`, `installPath`
- package type defaults to `opa`
- `extraFields` may include `sourcePath`, `inputKind`, `buildMode`, `outputs`, and `compilerVersion`

Runtime details:

- operations run through native `opa`
- wrapper reuses native target outputs as source of truth
- plugin inventory is advisory and stored in `inventory.tsv`
- list/search/info stay local-first and do not use network in v1

Security metadata summary:

- role: `package-manager`
- capabilities: `build`, `local-install`, `query`
- privilege: `none`
- ecosystem scope: `opa`

Test command:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
