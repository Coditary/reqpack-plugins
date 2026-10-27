# mill

ReqPack Lua wrapper for versioned `mill` launcher installs with one shared ReqPack-scoped cache/state root.

## Package forms

- `mill`
- `mill@1.0.4`
- `mill@0.12.11`

## Supported actions

- install exact or latest Mill launcher versions
- remove installed launcher versions
- update installed launcher versions to latest stable release
- list installed launcher versions
- search remote Mill releases
- inspect installed or remote version metadata
- install local launcher script artifacts

## Runtime and cache paths

- data root: `~/.local/share/reqpack/mill`
- cache root: `~/.cache/reqpack/mill`
- config root: `~/.config/reqpack/mill`
- managed launchers: `~/.local/share/reqpack/mill/bin`
- records: `~/.local/share/reqpack/mill/records`
- downloads: `~/.cache/reqpack/mill/downloads`
- Mill user cache: `~/.cache/reqpack/mill/user-cache`
- Coursier cache: `~/.cache/reqpack/mill/coursier`

## v1 limitations

- wrapper manages Mill launcher versions, not arbitrary project tasks
- `search` returns release versions, not example templates
- `installLocal()` expects local Mill launcher script artifact
- no project config mutation via `.mill-version` or `build.mill`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
