# hardhat

ReqPack wrapper for isolated Hardhat CLI installs.

## Package forms

- `hardhat`
- `hardhat@3.7.0`
- local `.tgz` tarball
- local unpacked npm package directory with `package.json`

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime and cache paths

- installs: ReqPack data root `hardhat/installs/<version>/`
- launchers: ReqPack data root `hardhat/bin/`
- records: ReqPack data root `hardhat/records/`
- registry cache: ReqPack cache root `hardhat/registry/hardhat.json`
- tarballs: ReqPack cache root `hardhat/tarballs/`
- npm cache: ReqPack cache root `hardhat/npm-cache/`

## Notes

- Plugin manages isolated Hardhat runtime copies.
- Plugin does not manage project-local Hardhat plugins or execute project tasks.
- Hardhat itself expects use from project-local installs.

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
