# reqpack-plugin-cpan

ReqPack Lua wrapper plugin for Perl `cpan`.

Plugin uses one plugin-owned CPAN cache and local install root.
It does not install into system Perl paths by default.

## Package Form

- `Try::Tiny`
- `name = "Try::Tiny", version = "0.32"`

Supported flags in `package.flags` or `context.flags`:

- `data-root=/path/to/root`
- `mirror=https://cpan.org`
- `prefer-mirror`
- `force`
- `notest`
- `sudo`

## Supported Actions

- install remote modules
- install local distributions from current dir or archive path
- update requested modules
- list managed installed modules
- show managed outdated modules
- inspect one module
- exact-like detail lookup via `search()`

## Runtime Paths

- CPAN home: `.reqpack-data/cpan-home/`
- local::lib root: `.reqpack-data/perl5/`

## v1 Notes

- `remove()` is intentionally unsupported because `cpan` has no reliable noninteractive uninstall command
- `search()` is detail lookup, not full fuzzy catalog search
- all commands pin plugin-local cache and install env
- version-pinned install requests use `<module>@<version>`

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
