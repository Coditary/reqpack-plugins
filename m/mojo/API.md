# API

## Accepted package names

- Mutating actions: `mojo`
- Query actions (`search`, `info`, `resolvePackage`): `mojo`, `modular`

Mutating actions only operate on `mojo`.

## Supported flags

- `modular-home=/path/to/.modular`
- `python-home=/path/to/python/home`
- `python-lib=/path/to/libpython`
- `clean` on remove to run `modular clean` after uninstall

## Behavior summary

- `install` runs `modular install mojo`
- `remove` runs `modular uninstall mojo`
- `update` runs `modular update mojo`, with fallback to `modular install mojo` if update subcommand is unsupported
- `list` and `info` inspect shared Modular state under one upstream cache root
- `search` is synthetic because upstream has no reliable package catalog search for this use case
- `outdated` returns `[]`
