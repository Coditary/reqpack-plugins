# EiffelStudio Plugin API

Supported ReqPack actions:

- `install(packages)` -> `iron install <name-or-uri>`
- `installLocal(path)` -> `iron install <path-or-file-uri>`
- `remove(packages)` -> `iron remove <name-or-uri>`
- `update(packages)` -> `iron update`
- `list()` -> `iron list --installed`
- `outdated()` -> returns empty list in v1
- `search(prompt)` -> `iron search <prompt>`
- `info(name)` -> `iron info <name-or-uri>`

Returned metadata when detectable:

- `name`, `packageId`, `version`, `installed`, `summary`, `description`
- `license`, `repository`, `installPath`, `homepage`
- `packageType` defaults to `library`
- `extraFields.nativeUri`, `extraFields.nativeId`, and unmatched info fields when present

Runtime details:

- operations run through native `iron`
- wrapper reuses native IRON state and repository configuration
- native cache/state path follows `IRON_PATH` then `ISE_IRON_PATH` then EiffelStudio defaults
- no plugin-owned cache is created in v1
- parser accepts simple line output and `Key: Value` info sections

Alias behavior:

- plugin id: `eiffelstudio`
- registry alias: `estudio`
- wrapped native executable: `iron`

Security metadata summary:

- role: `package-manager`
- capabilities: `exec`
- privilege: `none`
- ecosystem scope: `eiffel`

Test command:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
