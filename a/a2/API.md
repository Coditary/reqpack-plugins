# A2 Plugin API Notes

Plugin id: `a2`

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

Returned package type:

- `oberon-distribution`

Important behavior:

- all installed state is pinned to one managed ReqPack data root
- search, info, and outdated share one cached upstream revision file
- `source` means managed A2 repository profile, not host-global A2 installation
- local installs are tracked, but `update` is only supported for remote-managed packages

Test command:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
