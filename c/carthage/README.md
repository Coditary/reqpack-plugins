# Carthage Plugin

ReqPack wrapper for Carthage project dependencies.

## Package Forms

- GitHub dependency: `owner/repo`
- explicit declaration: `github "owner/repo" ~> 1.0`
- Git dependency: `https://host/repo.git`
- binary spec: `https://host/MyFramework.json`
- local repo path: `/path/to/repo` via `installLocal`
- local binary spec: `/path/to/MyFramework.json` via `installLocal`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime / Cache Paths

- shared home: `~/.cache/reqpack/carthage/home`
- shared Carthage cache: `~/.cache/reqpack/carthage/home/Library/Caches/org.carthage.CarthageKit`
- project manifest: `<project>/Cartfile`
- project lockfile: `<project>/Cartfile.resolved`
- project outputs: `<project>/Carthage/`

Override shared home with flag `home=/path`.
Override project directory with flag `dir=/path/to/project`.

## V1 Limits

- `search` is project-centric; Carthage has no central registry
- mutation actions require existing project `Cartfile`
- wrapper edits direct dependency lines only
- no automatic Xcode integration

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
