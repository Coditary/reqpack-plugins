# newlisp_bin API

## Actions

- `install`: installs official current release or requested historical source/Windows/macOS UTF8 release
- `installLocal`: installs from local source directory/archive or local executable
- `remove`: removes ReqPack-managed variant install
- `update`: updates requested or all installed variants to latest stable release
- `list`: returns registry-backed managed installs only
- `outdated`: compares installed variants against latest stable upstream release
- `search`: returns official variants and matching historical source/Windows binary releases
- `info`: returns installed or remote release metadata

## Flags

- `variant=<source|macos-utf8|win32|win32-utf8|win64|win64-utf8>`
- `data-root=<path>`
- `cache-root=<path>`
- `config-root=<path>`

## Behavior Notes

- installs are stored under ReqPack-owned data root
- remote metadata and downloads share common cache under ReqPack cache root
- `list()` does not inspect system installs outside ReqPack state
- remote items expose richer `extraFields` such as `channel`, `historySource`, `hostPlatform`, `archiveKind`, `fileName`, `releaseDate`, and `releaseNotesUrl`
- historical release dates fall back to SourceForge news when file listing lacks date data

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
rqp test-plugin --plugin ./run.lua --cases ./.reqpack-test/extra
```
