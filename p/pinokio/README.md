# pinokio

ReqPack Lua wrapper for Pinokio app install, script repositories, and shared artifact projection.

## What it manages

- app install via `app:pinokio`
- script repo lifecycle via `script:<git-url-or-owner-repo>`
- shared artifact projection via `artifact:<artifact-id>`

## Notes

- app runtime lives under `~/pinokio/app`
- script repos live under `~/pinokio/api`
- projected shared artifacts live under `~/pinokio/drive/reqpack/artifacts`
- plugin metadata lives under `~/pinokio/reqpack`
- canonical truth for shared artifacts stays in `~/.local/share/aicache`
- `installLocal()` unsupported in v1
- `search()` returns only static app hit in v1
- no Pinokio script execution or launcher flow in this plugin
- `outdated()` conservative/empty in v1

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
