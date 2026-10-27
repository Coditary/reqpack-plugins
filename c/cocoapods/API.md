# CocoaPods Plugin API

## Common Flags

- `dir=/path/to/project`
- `home=/path/to/shared/home`

## Install

Adds or updates direct `pod` declarations in `Podfile`, then runs `pod install`.

Extra flags:

- `repo-update`
- `clean-install`
- `deployment`

## Install Local

Supports:

- `.podspec`
- `.podspec.json`
- directory containing exactly one podspec

Adds dependency using `:podspec =>` or `:path =>`, then runs `pod install`.

## Remove

Removes matching direct `pod` declaration lines, then runs `pod install`.

## Update

Runs `pod update [pods...]`.

If package entries include `version`, plugin first updates matching `Podfile` declarations.

Extra flags:

- `repo-update`
- `clean-install`
- `sources=url1,url2`
- `exclude-pods=name1,name2`

## List

Reads installed project pods from `Podfile.lock`.

## Outdated

Runs `pod outdated` and parses outdated direct dependencies.

Extra flags:

- `repo-update`
- `ignore-prerelease`

## Search

Runs `pod search` and parses remote results.

Extra flags:

- `full`
- `stats`
- `ios`
- `osx`
- `watchos`
- `visionos`
- `tvos`

## Info

Combines installed state from `Podfile.lock` with remote podspec metadata from:

- `pod spec which`
- `pod ipc spec`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
