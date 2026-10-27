# newlisp_bin

ReqPack wrapper for official newLISP releases from `newlisp.org`, SourceForge files, and SourceForge news metadata.

## Package Forms

- `newlisp`
- `newlisp/source`
- `newlisp/macos-utf8`
- `newlisp/win32`
- `newlisp/win32-utf8`
- `newlisp/win64`
- `newlisp/win64-utf8`

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

- data: `~/.local/share/reqpack/newlisp_bin`
- cache: `~/.cache/reqpack/newlisp_bin`
- registry: `<data>/installed.tsv`
- installs: `<data>/installs/<variant>/<version>/`

## v1 Limitations

- query catalog covers official variants plus historical source, Windows, and macOS UTF8 releases
- source installs require host build tools
- one managed install per variant in registry-backed state
- release dates may come from SourceForge files or SourceForge news fallback
- remote metadata includes `releaseNotesUrl`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
rqp test-plugin --plugin ./run.lua --cases ./.reqpack-test/extra
```
