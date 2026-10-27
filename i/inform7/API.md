# inform7 API

Plugin id: `inform7`

Wrapped upstream tool:

- `inbuild`

Managed package type:

- Inform 7 extensions

Supported flags:

- `data-root=/path`
- `internal=/path`
- `nest=/path`

Behavior summary:

- `install`/`installLocal` copy local extension artifacts into ReqPack-managed external nest
- `list` inspects installed extensions in ReqPack external nest
- `search` inspects visible nests and filters matching extensions
- `info` resolves one extension from visible nests
- `remove` deletes only copies located inside ReqPack external nest
- `update` is no-op success in v1
- `outdated` returns empty list in v1

Test:

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
