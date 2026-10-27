# Corral API

## System Id

`corral`

## Package Record

- `name`: Corral locator
- `version`: optional Corral version constraint
- `revision`: optional exact revision
- `flags`: optional `revision=<value>` alternate

## Action Mapping

- install: `corral add ...` then `corral update`
- installLocal: `corral add <path>` then `corral update`
- remove: `corral remove <locator>` then `corral clean` and `corral update`
- update with packages: `corral add ...` for each package, then `corral clean` and `corral update`
- update without packages: `corral update`

Global Corral option used by wrapper:

```text
--bundle_dir ~/.cache/reqpack/corral/bundle
```

## Query Semantics

- `list()` returns direct deps stored in shared `corral.json`
- `info()` resolves from shared `corral.json` and `lock.json`
- `search()` returns `[]`
- `outdated()` returns `[]`

## Important Notes

- cache bundle is plugin-owned state
- `_repos` and `_corral` stay together with `corral.json` and `lock.json`
- removing package clears desired state from shared bundle; underlying VCS repo cache may remain in `_repos`
