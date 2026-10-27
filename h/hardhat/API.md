# API

## Supported requests

### install

- `hardhat`
- `hardhat@<version>`
- `{ name = "hardhat", version = "<version>" }`

Default without version resolves npm `latest`.

### installLocal

- `.tgz` npm tarball
- unpacked directory containing `package.json`

### remove

- removes ReqPack-managed installed versions only
- leaves shared tarball and metadata cache intact

### update

- updates targeted installed entries to npm `latest`
- no package list: updates all outdated installed entries

### list

Returns ReqPack-managed installed Hardhat runtimes only.

### outdated

Compares installed versions against npm `dist-tags.latest`.

### search

Searches cached/live npm metadata for package name and version matches.

### info

Supports:

- `hardhat`
- `hardhat@<version>`

## Extra fields

- `launcherPath`
- `installPath`
- `recordPath`
- `tarballPath`
- `cacheRoot`
- `npmCacheDir`
- `sourceKind`
- `distTagLatest`
