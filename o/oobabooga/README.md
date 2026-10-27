# oobabooga

ReqPack Lua wrapper for text-generation-webui portable app install plus local and shared-model projection.

## What it manages

- portable app install via `app:oobabooga`
- local model projection via `local:/absolute/path`
- shared-cache model projection via `aicache:<artifact-id>`

## Notes

- canonical truth for shared artifacts stays in `~/.local/share/aicache`
- runtime projection lives under `~/.local/share/oobabooga`
- plugin metadata lives under `~/.local/share/oobabooga/reqpack`
- portable app install root is `~/.local/share/oobabooga/app`
- projected models root is `~/.local/share/oobabooga/app/user_data/models`
- `remove` deletes projection, not canonical AICache bytes
- `installLocal()` supports absolute local paths
- `search()` returns only static app hit in v1
- `outdated()` conservative/empty in v1

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
