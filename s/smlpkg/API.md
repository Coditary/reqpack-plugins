# smlpkg Plugin API

## Command Mapping

- install: `smlpkg add <pkg> [version]` per package, then `smlpkg sync`
- remove: `smlpkg remove <pkg>` per package, then `smlpkg sync`
- update: `smlpkg upgrade`, then `smlpkg sync`
- info/outdated: `smlpkg versions <pkg>`

## Notes

- package identity is exact package path like `github.com/diku-dk/sml-random`
- local state comes from `sml.pkg` and `lib/`
- `search` unsupported by upstream, returns `[]`
- `installLocal` unsupported by upstream, returns failure
