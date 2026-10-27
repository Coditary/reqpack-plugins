# oobabooga API

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Package forms

- `app:oobabooga`
- `local:/absolute/path`
- `aicache:<artifact-id>`

## Behavior summary

- app install/update manages portable runtime files
- `local:` projects local model file or directory into runtime models root
- `aicache:` projects shared artifact into runtime models root
- plugin metadata stored under `~/.local/share/oobabooga/reqpack`
- app runtime root is `~/.local/share/oobabooga/app`
- projected models root is `~/.local/share/oobabooga/app/user_data/models`
- `list/info` prefer plugin-managed projection metadata, then shared-cache metadata
- `search()` only returns static `app:oobabooga` hit in v1
- `outdated()` returns empty list in v1
