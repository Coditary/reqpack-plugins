# vim-plug

ReqPack wrapper for `vim-plug` plugin declarations and headless install or update flows.

## Package Forms

- `owner/repo`
- full git URL like `https://github.com/tpope/vim-fugitive.git`
- local plugin directory through `installLocal()` or request `localPath`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime And Cache Paths

- data: `~/.local/share/reqpack/vim-plug`
- cache: `~/.cache/reqpack/vim-plug`
- config: `~/.config/reqpack/vim-plug`
- shared clone root: `~/.local/share/reqpack/vim-plug/plugged`
- generated vimrc: `~/.config/reqpack/vim-plug/reqpack.vim`

## v1 Limits

- no user `.vimrc` or `init.vim` mutation
- no global package registry search; `search()` uses exact repo-like queries plus local/cache fuzzy results
- external local/custom dirs are deregistered on remove, not deleted

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
