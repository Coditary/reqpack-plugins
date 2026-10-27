# ghskill

ReqPack Lua wrapper for GitHub CLI `gh skill` with shared-cache-aware skill projection.

## Dependency

`reqpack.lua` depends on:

```lua
depends = { "nix:gh" }
```

## What it manages

- launcher availability via `app:ghskill`
- concrete skill installs from GitHub repos
- canonical AICache artifacts for source repos and installed skills
- runtime projections into supported agent skill directories

## Package forms

- `app:ghskill`
- `owner/repo/skill-name`
- `owner/repo/skills/namespace/skill-name`

## Notes

- repo-only install like `owner/repo` intentionally unsupported in v1
- `installLocal()` unsupported in v1
- `list/info` enrich installed skill projections from `SKILL.md` frontmatter when available
- `outdated()` uses conservative targeted `gh skill update <skill> --dry-run`
- canonical cache lives in `~/.local/share/aicache`
- plugin metadata lives in `~/.local/share/ghskill/reqpack`
- runtime projections live in `.agents/skills` or `~/.config/opencode/skills`
- `list()` also shows cache-only repo and skill views when present

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
