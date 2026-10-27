# sbt

ReqPack Lua wrapper for sbt dependency resolution and cache warming.

## Package Forms

- `group:artifact`
- `group:artifact:version`
- `{ name = "group:artifact", version = "1.2.3" }`
- `{ group = "group", artifact = "artifact", version = "1.2.3" }`

## Supported Actions

- `install`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime And Cache Paths

Default plugin-managed root:

- `.reqpack-data/`

Inside root:

- `deps.json` tracked dependencies
- `sbt-project/` generated synthetic sbt project
- `sbt-global/` shared sbt global base
- `sbt-boot/` shared sbt boot cache
- `ivy2/` shared Ivy cache
- `coursier/` shared Coursier cache
- `query/` Maven Central query cache

Override root with flag:

- `data-root=/path/to/root`

## Major v1 Limitations

- manages plugin-owned synthetic sbt project, not user `build.sbt`
- `install` and `update` require explicit version
- `installLocal()` unsupported
- `outdated()` intentionally returns empty list
- `search` and `info` use Maven Central API, not arbitrary custom resolvers

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
