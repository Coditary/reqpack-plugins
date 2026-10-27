# gh

ReqPack Lua wrapper for GitHub CLI `gh`.

## Dependency

`reqpack.lua` depends on:

```lua
depends = { "nix:gh" }
```

## What it manages

- launcher availability via `app:gh`
- GitHub CLI extensions via `gh extension`
- agent skills in plugin-managed shared directories via `gh skill`
- CodeQL CLI versions via official `github/gh-codeql` extension

## Package forms

- `app:gh`
- `owner/gh-extension`
- `owner/repo/skill-name`
- `owner/repo/skills/namespace/skill-name`
- `codeql`
- `codeql@<version>`

## Runtime and cache paths

- shared cache root: `~/.cache/reqpack/gh`
- gh config root: `~/.cache/reqpack/gh/config`
- managed skills root: `~/.cache/reqpack/gh/skills`
- plugin state: `~/.cache/reqpack/gh/state`

## v1 notes

- wraps installable `gh` artifacts only, not arbitrary GitHub objects like issues or PRs
- `installLocal()` unsupported
- extension `outdated()` stays conservative and returns no extension updates in v1
- skills install into plugin-managed shared directories, not caller repo `.agents/skills`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
