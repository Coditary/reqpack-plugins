# rqp-plugin-zinit

ReqPack Lua plugin for `zinit`.

Plugin wraps `zinit` through a dedicated ReqPack-managed Zinit home and manifest.

## Package Forms

- `name=<user/repo>` for regular plugins
- `name=<url>` with `flags={"snippet"}` for remote snippets
- `localPath=<absolute-dir>` for local plugin directories
- `localPath=<absolute-file>` for local snippet files

Examples:

```bash
rqp install zinit zsh-users/zsh-autosuggestions
rqp install zinit https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/git/git.plugin.zsh --flags snippet
```

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`
- `resolvePackage`

## Shared Cache And Runtime Paths

- `~/.local/share/reqpack/zinit/home`
- `~/.local/share/reqpack/zinit/home/zinit.git`
- `~/.local/share/reqpack/zinit/packages.tsv`
- `~/.local/share/reqpack/zinit/packages.zsh`
- `~/.cache/reqpack/zinit/zcompdump`

Plugin keeps one shared managed Zinit home for plugins, snippets, completions, and stored `._zinit` metadata.

## v1 Notes

- wrapper does not edit user `.zshrc`
- remote search is limited to ReqPack-managed manifest entries
- outdated detection is git-only for managed plugin repos
- local targets are removed from ReqPack manifest without deleting user source files

## Testing

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
