# smackage Plugin API

## Command Mapping

- install: `smackage get <name> [version]`
- update: `smackage update`
- list: `smackage list`
- search: `smackage search <name> [version]`
- info: `smackage info <name> [version]`
- outdated: `smackage refresh`, then `smackage info <name>` for installed roots

## Notes

- state lives under `SMACKAGE_HOME`, default `~/.smackage`
- explicit user roots come from `packages.installed`
- `remove` unsupported by upstream
- `installLocal` unsupported by upstream
