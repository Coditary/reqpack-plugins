# Conda Wrapper API Notes

Short operator-facing reference for this Conda ReqPack wrapper.

## Supported Actions

- `install(context, packages)`
- `installLocal(context, path)`
- `remove(context, packages)`
- `update(context, packages)`
- `list(context)`
- `search(context, prompt)`
- `info(context, name)`
- `outdated(context)`
- `resolvePackage(context, package)`
- `getMissingPackages(packages)`

## Command Mapping

- install package: `conda install --yes --json <target> <spec>`
- install local archive: `conda install --yes --json <target> <path>`
- install local spec file: `conda install --yes --json <target> --file <path>`
- remove package: `conda remove --yes --json <target> <spec>`
- update package: `conda update --yes --json <target> <spec>`
- update all: `conda update --yes --json <target> --all`
- list: `conda list --json <target>`
- search: `conda search --json [flags] <query>`
- info: `conda search --info --json [flags] <query>`

`<target>` is either `--prefix <path>`, `--name <env>`, or omitted when no target could be inferred.

## Supported Local Inputs

- `.conda`
- `.tar.bz2`
- `.txt`
- `.json`
- `.yaml`
- `.yml`

Rules:

- `.conda` and `.tar.bz2` install as direct positional artifacts
- `.txt`, `.json`, `.yaml`, `.yml` install through `--file`
- other extensions are rejected

## Prompt Shortcuts For `search()`

- `channel:<channel> <query>`
- `subdir:<subdir> <query>`
- `local <query>`

Examples:

- `channel:conda-forge zlib`
- `subdir:linux-64 numpy`
- `local pytorch`

## Returned Package Fields

Primary fields returned when available:

- `name`
- `packageId`
- `version`
- `latestVersion`
- `installed`
- `status`
- `summary`
- `description`
- `homepage`
- `sourceUrl`
- `license`
- `repository`
- `dependencies`
- `packageType = "conda"`
- `type = "package"`

Common `extraFields`:

- `channel`
- `build`
- `buildNumber`
- `fn`
- `subdir`
- `requestedSpec`
- `prefix` or `environment`

## Planning Behavior

`getMissingPackages(packages)` filters work like this:

- install local path: always keep
- install package: keep when absent or exact requested version differs
- remove package: keep only when installed
- update package with explicit version: keep when installed version differs
- update package without explicit version: keep only when remote newer version exists

If Conda query path fails, wrapper returns original package list conservatively.

## Query Behavior

- `list()` reads installed packages from target environment only
- `search()` reads remote/index metadata and deduplicates to best record per `channel/name`
- `info()` merges installed record with best remote metadata when available
- `outdated()` compares installed packages against best remote candidate per package

## Security Metadata

Wrapper declares:

- role: `package-manager`
- capabilities: `exec`, `network`
- ecosystem: `conda`
- write scopes: `~/.conda`, `~/.cache/conda`
- privilege level: `user`

## Test Command

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
