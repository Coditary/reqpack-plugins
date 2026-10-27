# ghskill API

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Flags

- `agent=<id>`
- `scope=user`
- `scope=project`
- `dir=<absolute-path>`
- `pin=<tag-or-sha>`
- `force`
- `allow-hidden-dirs`
- `upstream`

## Behavior summary

- `install app:ghskill` records `gh` launcher metadata
- skill install wraps `gh skill install <repo> <selector>`
- `list/info` enrich projection info from installed `SKILL.md` frontmatter when present
- frontmatter keys used when available:
  - `metadata.github-repo`
  - `metadata.github-ref`
  - `metadata.github-tree-sha`
  - `metadata.github-path`
  - `metadata.github-pinned`
  - `metadata.skillFolderHash`
- `outdated` checks plugin-managed skills via `gh skill update <skill> --dry-run`
- repo-only `install` is rejected in v1
- `list` also shows cache-only repo and skill views from `~/.local/share/aicache/views/by-source/ghskill`
