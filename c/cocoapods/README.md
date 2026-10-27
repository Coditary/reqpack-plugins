# CocoaPods Plugin

ReqPack wrapper for CocoaPods project dependencies.

## Package Forms

- remote pod: `AFNetworking`
- remote pod with version: `AFNetworking` + `version = "4.0.1"`
- local podspec: `/path/to/MyLib.podspec`
- local pod directory with one podspec: `/path/to/MyLib/`

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

- shared CocoaPods home: `~/.cache/reqpack/cocoapods/home`
- specs/repos: `~/.cache/reqpack/cocoapods/home/.cocoapods/repos`
- cache: `~/.cache/reqpack/cocoapods/home/Library/Caches/CocoaPods`

Override shared home with flag `home=/path`.
Override project directory with flag `dir=/path/to/project`.

## V1 Limits

- mutation actions require existing project `Podfile`
- plugin edits direct `pod ...` declarations only
- no full Ruby Podfile AST support

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
