# reqpack-plugin-conda

ReqPack wrapper plugin for Conda.

Plugin manages Conda packages in one target environment through `conda` CLI.

## Scope

- installs Conda packages into one target environment
- installs local `.conda` and `.tar.bz2` artifacts
- installs local package/env spec files through `--file`
- removes and updates installed Conda packages
- lists installed packages from target environment
- searches remote Conda packages
- shows merged installed and remote package info
- reports outdated packages by comparing installed records against remote search results

Wrapper does not create or remove environments in v1.

## Package Forms

- plain package name: `python`
- exact version: `python=3.12`
- comparator form: `python>=3.12`
- optional request flags: `channel=conda-forge`, `subdir=linux-64`, `override-channels`, `no-deps`, `only-deps`, `force-reinstall`, `freeze-installed`, `use-local`, `offline`, `use-index-cache`, `no-pin`, `copy`

## Environment Targeting

Wrapper targets one Conda environment per request.
Target resolution order:

- `context.prefix`
- `context.environment` or `context.env`
- `context.request.prefix`
- `context.request.environment` or `context.request.env`
- inferred base prefix from `conda info --json`
- active Conda environment if no target could be inferred

Commands use either `--prefix <path>` or `--name <env>`.

## Runtime And Cache Paths

Shared Conda cache paths used by native CLI:

- `~/.conda`
- `~/.cache/conda`

Plugin does not create separate package cache.
`search()`, `info()`, and `outdated()` reuse Conda repodata cache through native `conda search`.

## Files

- `metadata.json`: bundle metadata and plugin id
- `reqpack.lua`: bundle manifest
- `run.lua`: Conda wrapper implementation
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `.reqpack-test/core/*.lua`: hermetic plugin tests
- `API.md`: Conda wrapper behavior summary

## Limitations

- no env create/remove support in v1
- no per-package mixed environment targets in one request
- `outdated()` is computed by per-package remote lookups, not single native outdated command
- shared package cache behavior is delegated fully to Conda

## Running Tests

Run plugin conformance tests from plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```

Run one case directly:

```bash
rqp test-plugin --plugin ./run.lua --case ./.reqpack-test/core/info.lua
```
