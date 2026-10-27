# rqp-plugin-octave-forge

ReqPack Lua wrapper plugin for Octave Forge packages for GNU Octave.

Supports:

- remote install from Octave package index with `pkg install -forge`
- local install from package archive or URL
- managed local/global package stores under one shared plugin state root
- `list`, `outdated`, `search`, and `info` from GNU Octave metadata and `packages.octave.org`

## Package Forms

- package name like `image`
- local archive like `./image-2.16.1.tar.gz`
- direct URL accepted by `pkg install`

## Runtime Paths

Default state root:

- `.reqpack-data/home`
- `.reqpack-data/prefix`
- `.reqpack-data/arch-prefix`
- `.reqpack-data/local/octave_packages`
- `.reqpack-data/global/octave_packages`
- `.reqpack-data/cache/packages.json`
- `.reqpack-data/config`
- `.reqpack-data/tmp`

Override with request flag:

- `data-root=/path/to/state`

## v1 Limitations

- remote exact-version install is not supported by GNU Octave `pkg`; named installs use latest available release
- host-global Octave package stores are not modified; `global` means managed global store inside plugin state root
- package load/unload/test actions are not wrapped in v1

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
