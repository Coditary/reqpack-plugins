# flix

ReqPack wrapper for Flix package management.

## Package Forms

- remote package: `owner/repo`
- optional version: SemVer tag without or with leading `v`
- optional security: `plain`, `paranoid`, or `unrestricted`
- local project path for `installLocal()`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime And Cache Paths

- synthetic project root: `.reqpack-data/flix-cache/`
- synthetic manifest: `.reqpack-data/flix-cache/flix.toml`
- shared Flix dependency cache: `.reqpack-data/flix-cache/lib/`
- GitHub metadata cache: `.reqpack-data/flix-cache/github/`

## Major v1 Limitations

- search and info are GitHub-backed heuristics, not an official Flix catalog
- remove does not prune already-downloaded dependency artifacts from cache
- local install builds package artifact with `flix build-pkg`; it does not register a global package
- bare repo names can be ambiguous; prefer `owner/repo`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
