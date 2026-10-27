# nuget API

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`
- `resolvePackage`

## Flags

- `source=<feed-or-path>`
- `cache-root=<path>`
- `prerelease`
- `directdownload`
- `excludeversion`
- `save=nupkg`
- `save=nuspec`
- `save=nupkg;nuspec`

## Behavior summary

- `install` wraps `nuget install` into ReqPack cache directory
- `installLocal` stages `.nupkg` into local hierarchical feed with `nuget add`, then installs from that feed
- `remove` deletes matching directories from ReqPack-managed cache only
- `update` refreshes package by reinstalling into same cache root
- `list` shows packages discoverable from ReqPack-managed cache source
- `search` wraps remote `nuget search`
- `info` prefers installed cache view, then enriches with remote NuGet metadata
- `resolvePackage` resolves single NuGet package id/version into normalized ReqPack package metadata
- `outdated` returns empty in v1 because NuGet CLI lacks reliable cache-wide update reporting
