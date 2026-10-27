# rqp-plugin-a2

ReqPack Lua wrapper plugin for A2 Oberon distribution profiles.

Supports:

- managed installs of stable A2 profiles like `linux64`, `linux32`, `win64`, `win32`, `arm`, `unixaos`, `source`, `aosvm`, and `documentation`
- local install from matching directory or archive names
- shared cache for upstream revision metadata and installed package manifests
- `list`, `outdated`, `search`, and `info` from one managed state root

## Package Forms

- profile name like `linux64`
- alias like `linux-64`, `docs`, `unix-aos`
- local directory like `./Linux64`
- local archive like `./Linux64.zip`

## Runtime Paths

Default state root:

- `.reqpack-data/cache/repository.json`
- `.reqpack-data/installs/<package>/manifest.json`
- `.reqpack-data/installs/<package>/payload/`
- `.reqpack-data/tmp`

Override with request flag:

- `data-root=/path/to/state`

## v1 Limitations

- remote installs manage A2 profile metadata and payload markers inside ReqPack state root; they do not install host-global launchers into `/usr/local/bin`
- plugin wraps documented A2 distribution profiles, not arbitrary community modules inside repository history
- local archive install infers package id from archive file name only

## Running Tests

From plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
