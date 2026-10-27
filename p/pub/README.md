# rqp-plugin-pub

ReqPack Lua plugin for Dart `pub` global packages.

Plugin wraps `dart pub global` for install/update/remove/list and uses documented pub.dev APIs for `search`, `info`, and `outdated` enrichment.

## Package Syntax

- `package-name`
- `package-name` with explicit `version`
- local path through ReqPack `localPath`

Examples:

```bash
rqp install pub melos
rqp install pub dart_dev --version 6.0.0
rqp install pub --local-path ./tools/my_cli
```

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`
- `resolvePackage`

## Cache Behavior

- all CLI actions run with shared `PUB_CACHE` under `~/.cache/reqpack/pub/pub-cache`
- remote query cache lives under `~/.cache/reqpack/pub/query`
- `list` inspects `PUB_CACHE/bin` to infer exposed executables when possible

## Testing

Run hermetic plugin tests from plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
