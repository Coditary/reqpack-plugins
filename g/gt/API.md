# gt Plugin API

## Request fields

- `name`: `gt` or `genometools`
- `version`: GenomeTools release version without leading `v`
- `localPath`: local GenomeTools source tree for `installLocal`

## Supported flags

- `data-root=/abs/path`
- `jobs=<n>`
- `cairo=no`
- `useshared=yes`
- `assert=no`
- `opt=no`
- `errorcheck=no`
- `verbose=yes`
- `64bit=no`
- `32bit=yes`
- `amalgamation=yes`

## Behavior notes

- remote metadata comes from GitHub releases API
- install builds from tarball with `make` and `make prefix=... install`
- installLocal reads local `VERSION` file when present; otherwise uses `0.0.0-local`
- update installs latest release without deleting older managed versions
