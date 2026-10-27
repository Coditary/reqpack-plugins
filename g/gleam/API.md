# API

## Request mapping

- `install`: `gleam add <pkg>` or `gleam add --dev <pkg>`
- `remove`: `gleam remove <pkg>`
- `update`: `gleam update [pkg ...]`
- `list`: parse `manifest.toml`, fallback `gleam deps list`
- `outdated`: parse `gleam deps outdated`
- `search`: `curl https://hex.pm/api/packages?search=<prompt>`
- `info`: installed entry from `manifest.toml` or `curl https://hex.pm/api/packages/<name>`

## Flags

- package flag `dev`: install into `[dev_dependencies]`
- context/request flag `cwd=/path/to/project`: use explicit project root

## v1 limitations

- no direct local install support
- Hex query paths require `curl`
- list/info parse lock manifest entries, not full dependency tree metadata from Gleam internals
