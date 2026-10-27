# gh API

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Package kinds

- `app`
- `extension`
- `skill`
- `codeql`

## Flags

- CodeQL:
  - `channel=release`
  - `channel=nightly`
- Skills:
  - `force`
  - `upstream`

## Behavior summary

- `app:gh` reflects `gh` launcher availability only
- extensions wrap `gh extension install/remove/search/list`
- skills wrap `gh skill install/search` and use plugin-managed `--dir` targets
- CodeQL wraps `gh codeql` lifecycle through official `github/gh-codeql` extension
- CodeQL state is cached in plugin state for deterministic list/info/outdated behavior
- `installLocal()` is intentionally unsupported in v1
