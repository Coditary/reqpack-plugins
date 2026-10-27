# reqpack-plugin-dpkg

ReqPack Lua wrapper for Debian package management.

## Supported Operations

- `install`: `apt-get install -y`
- `installLocal`: `dpkg -i` for local `.deb` files
- `remove`: `dpkg -r`
- `update`: `apt-get install --only-upgrade -y`
- `list`: installed packages from `dpkg-query`
- `search`: repository search via `apt-cache search`
- `info`: merged installed and repository metadata from `dpkg-query`, `apt-cache policy`, and `apt-cache show`
- `outdated`: upgradable packages via `apt list --upgradable`

## Files

- `run.lua`: main wrapper implementation
- `metadata.json`: bundle metadata
- `reqpack.lua`: bundle manifest
- `scripts/install.lua`: required bundle hook stub
- `scripts/remove.lua`: required bundle hook stub
- `.reqpack-test/core/*.lua`: hermetic plugin tests
- `API.md`: local API quick reference

## Test

```bash
rqp test-plugin --plugin . --preset core
rqp test-plugin --plugin . --cases ./.reqpack-test/failures
```

Real Debian smoke steps: see `SMOKE.md`.
