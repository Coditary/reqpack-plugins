# API

## Behavior Summary

- `install()`: rewrites target `rebar.config`, runs `rebar3 update`, then `rebar3 get-deps`
- `installLocal()`: adds local git dependency and runs `rebar3 get-deps`
- `remove()`: removes direct dependency entries and runs `rebar3 unlock <deps>`
- `update()`: optionally rewrites explicit versions, then runs `rebar3 update` and `rebar3 upgrade`
- `list()`: returns direct dependencies from target `rebar.config`
- `outdated()`: compares exact declared package versions against latest remote package metadata
- `search()`: exact lookup using `rebar3 pkgs <name>`
- `info()`: merges local declaration state with remote `rebar3 pkgs` metadata

## Supported Flags

- `dir=/path/to/project`: target real rebar3 project instead of shared synthetic project

## Notes

- shared environment uses `REBAR_CACHE_DIR` and `REBAR_GLOBAL_CONFIG_DIR`
- real project mode still lets `rebar3` manage project-local `rebar.lock` and `_build/`
- source dependency rendering is conservative and does not try to support every Erlang dependency form
