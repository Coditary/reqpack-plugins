# odpkg

ReqPack wrapper for `odpkg`, unofficial Odin package manager.

## Package forms

- repo spec: `owner/repo`
- repo spec with ref: `owner/repo` plus `version = "v1.2.3"`
- explicit repo field: `name = "alias", repo = "owner/repo"`
- registry slug: package name plus `flags = { "registry" }`

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

`installLocal()` is intentionally unsupported because upstream `odpkg` has no local artifact install command.

## Runtime and cache paths

- project manifest: `<project>/odpkg.toml`
- project lockfile: `<project>/odpkg.lock`
- project vendor dir: `<project>/<vendor_dir>`
- shared registry cache: `~/.cache/odpkg/packages.json`
- optional cache override: `cache-home=<path>` -> `<path>/odpkg/packages.json`

## v1 limitations

- mutating operations require existing project root with `odpkg.toml`
- install works by `odpkg add ...` then `odpkg install`
- update is whole-project only
- outdated always returns empty because upstream has no honest outdated query

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
