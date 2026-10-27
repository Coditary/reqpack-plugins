# rebar3 ReqPack Plugin

ReqPack wrapper for `rebar3` Erlang dependency management.

## Package Forms

- remote package latest: `rebar3:cowboy`
- remote package explicit version: `rebar3:cowboy@2.10.0`
- local git repo via `installLocal`: path request with optional package name

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search` exact package lookup only
- `info`

## Runtime And Cache Paths

- shared cache root: `~/.cache/reqpack/rebar3`
- shared `rebar3` cache: `~/.cache/reqpack/rebar3/cache`
- shared `rebar3` config: `~/.cache/reqpack/rebar3/config`
- synthetic project: `~/.cache/reqpack/rebar3/project`

## Major v1 Limitations

- `rebar3` is project-local dependency manager, not true global package manager
- `search()` is exact-match lookup via `rebar3 pkgs <name>`
- `installLocal()` supports local git repositories only
- `outdated()` reports only exact-version package dependencies, not ranges or source deps

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
