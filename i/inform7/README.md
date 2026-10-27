# inform7

ReqPack plugin for Inform 7 extension management through upstream `inbuild` CLI.

Package forms:

- local `.i7x` extension file
- local `.i7xd` extension bundle directory
- extension title for `list`, `search`, `info`, `remove`

Supported actions:

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

Runtime/cache paths:

- default root: `~/.cache/reqpack/inform7`
- external nest: `~/.cache/reqpack/inform7/external`
- temp dir: `~/.cache/reqpack/inform7/tmp`

Important v1 limits:

- no remote download/fetch from Inform Public Library
- install paths must point to local `.i7x` or `.i7xd` artifacts
- `outdated()` returns empty list by design
- wrapper manages Inform extensions, not project builds

Test:

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
