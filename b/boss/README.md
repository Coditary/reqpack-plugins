# Boss

ReqPack Lua wrapper for Boss package manager for Delphi and Lazarus.

## Package forms

- `horse`
- `hashload/horse`
- `github.com/HashLoad/horse`
- `https://gitlab.com/example/pkg`

ReqPack `package.version` maps to `boss install name@version`.

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

`search` and `info` are cache-local/query-local because Boss CLI does not expose stable remote catalog commands.

## Runtime and cache paths

- Boss home default: `~/.boss`
- Boss cache default: `~/.boss/cache`
- with ReqPack flag `cache-root=<path>`:
  - Boss home: `<path>/home`
  - Boss cache: `<path>/home/cache`
  - plugin state: `<path>/state`

## v1 limits

- no true remote catalog search
- `outdated` depends on Boss cache info files already existing
- `installLocal` restores dependencies for local Boss project directory, not archive install

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
