# reqpack-plugin-cpanm

ReqPack Lua wrapper plugin for Perl `cpanm`.

Plugin uses one plugin-owned cpanminus cache and local install root.
It does not install into system Perl paths by default.

## Package Form

- `Plack`
- `name = "Plack", version = "1.0051"`

Supported flags in `package.flags` or `context.flags`:

- `data-root=/path/to/root`
- `mirror=https://cpan.metacpan.org`
- `from=https://cpan.metacpan.org`
- `mirror-only`
- `version-range=>= 1.0, < 2.0`
- `force`
- `notest`
- `sudo`
- `dev`
- `reinstall`
- `self-contained`
- `exclude-vendor`
- `cascade-search`
- `skip-installed`
- `skip-satisfied`

## Supported Actions

- install remote modules
- install local dirs and archives
- remove managed modules
- update requested modules by reinstalling latest
- list managed installed modules
- inspect one module via `--info`
- exact-like detail lookup via `search()`

## Runtime Paths

- cpanm home: `.reqpack-data/cpanm-home/`
- local::lib root: `.reqpack-data/perl5/`

## v1 Notes

- `search()` is exact lookup, not full fuzzy catalog search
- `outdated()` returns empty list because `cpanm` has no honest built-in outdated listing without custom HTTP logic
- all commands pin plugin-local cache and install env
- version pin uses `name@version`; ranges use `name~constraint`

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
