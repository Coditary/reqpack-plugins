# Octave Forge Plugin API Notes

Plugin id: `octave-forge`

Supported actions:

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`
- `resolvePackage`

Request flags:

- `data-root=/path`
- `refresh`
- `nodeps`
- `verbose`
- `local`
- `global`

Returned package type:

- `octave-package`

Important behavior:

- all package state is pinned to one managed ReqPack data root
- search/info/outdated share one cached `packages.json`
- `global` writes to managed global list inside plugin state root, not host system paths
- named remote installs and updates use latest available package release

Test command:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
