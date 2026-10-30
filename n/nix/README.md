# rqp-plugin-nix

ReqPack Lua plugin for native `nix` installations.

Plugin wraps modern `nix profile` workflow for install, remove, update, and list operations. It uses `nix search` for `search`, `info`, `outdated`, and package resolution.

## Behavior

- bootstraps Nix when no working `nix` binary is available: **`context.net.download`** fetches the official installer, then **`sh`** runs it (`--daemon` on Linux with systemd, `--no-daemon --yes` without systemd, plain `sh` on macOS)
- **`scripts/install.lua`** is a no-op; bootstrap runs from `run.lua` where `context.net` exists
- passes `--extra-experimental-features 'nix-command flakes'` on every Nix CLI call so `profile` and `search` work without host config changes
- maps simple names like `hello` to `nixpkgs#hello`
- keeps explicit installables unchanged, for example `nixpkgs#hello`, `github:owner/repo#pkg`, `.#pkg`, `/path/to/flake`
- uses `nix profile list --json` for installed-state checks and listing
- reports outdated mutable `nixpkgs` installs by comparing installed profile version with current `nix search` result

## Supported ReqPack Paths

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `search`
- `info`
- `resolvePackage`

## Testing

Run hermetic plugin tests from plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```

## Notes

- `installLocal()` treats local path as native Nix installable and forwards it to `nix profile install`
- package-specific updates rely on Nix profile entry names and only run when newer version is detected
- exact package pinning through separate ReqPack `version` field is not supported by `nix profile`; use explicit Nix installables when needed
