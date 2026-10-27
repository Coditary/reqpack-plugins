# gt ReqPack Plugin

ReqPack wrapper for GenomeTools `gt`.

## Package forms

- `gt`
- `gt@1.6.4`
- `genometools@1.6.4`

## Supported actions

- `install`: build upstream release tarball into shared ReqPack root
- `installLocal`: build local GenomeTools source tree into shared ReqPack root
- `remove`: remove wrapper-managed installed version
- `update`: install latest upstream release additively
- `list`: list wrapper-managed installs
- `outdated`: compare wrapper-managed installs with latest upstream release
- `search`: search upstream releases
- `info`: show one installed or upstream release record

## Runtime and cache paths

- default managed root: `~/.reqpack-data/gt`
- installs: `~/.reqpack-data/gt/installs/<version>`
- downloads: `~/.reqpack-data/gt/downloads/`
- extracted sources: `~/.reqpack-data/gt/src/`

Override root with flag `data-root=/abs/path`.

## Important v1 limits

- manages only wrapper-owned installs, not apt/brew/system installs
- builds from source tarballs; no binary package flow
- keeps cached tarballs and extracted source trees on remove

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
