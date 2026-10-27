# smackage ReqPack Plugin

Thin ReqPack wrapper for `smackage`.

## Package Forms

- `cmlib`
- `twelf`
- exact or constrained version via ReqPack `version`

## Supported Actions

- `install`
- `update`
- `list`
- `outdated`
- `search`
- `info`

`remove` is unsupported because upstream `smackage` has no uninstall command.
`installLocal` is unsupported.

## Runtime And Cache Paths

- default home: `~/.smackage`
- override: `SMACKAGE_HOME`
- installed packages: `$SMACKAGE_HOME/lib`
- explicit installs: `$SMACKAGE_HOME/packages.installed`

## v1 Limits

- `update` updates global explicit roots, not selected subset
- `remove` unsupported upstream
- metadata comes from plain-text `smackage` commands only

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
