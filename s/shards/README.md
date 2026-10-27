# shards plugin

ReqPack wrapper for Crystal `shards` projects.

`shards` is project-local, not global. Mutating actions work against a Crystal project directory containing `shard.yml`.

## Package forms

- `name=kemal`
- `name=kemal version=~> 1.11`
- `name=kemal flags=github=kemalcr/kemal`
- `name=athena flags=gitlab=athena-framework/athena`
- `name=mydep flags=bitbucket=workspace/mydep`
- `name=mydep flags=codeberg=owner/mydep`
- `name=jwt flags=git=https://github.com/crystal-community/jwt.git,branch=main`
- local install: `installLocal(<path>)` where path contains `shard.yml`

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Important flags

- `dir=/path/to/project`
- `path=/path/to/project`
- `cache-root=/custom/cache/root`

## Runtime and cache paths

- shared cache root: `~/.cache/reqpack/shards`
- shards remote cache: `~/.cache/reqpack/shards/shards-cache`
- search cache: `~/.cache/reqpack/shards/search`
- info cache: `~/.cache/reqpack/shards/info`

## v1 limitations

- manifest writer supports common simple `shard.yml` layouts only
- resolver support covers `github`, `gitlab`, `bitbucket`, `codeberg`, `git`, `path`, `version`, `branch`, `tag`, `commit`
- `search` and `info` use `shards.info`, not native `shards` CLI
- `search` and `info` are best-effort for non-GitHub ecosystems because public shard indexing is GitHub-centric

## Behavior notes

- `install` and `remove` edit `shard.yml`, then reconcile with `shards install`
- `update` calls `shards update` and rewrites manifest first when explicit resolver/version flags are provided
- `remove` also runs `shards prune` to clean unused dependencies from `lib/`
- `list` and `outdated` are read-only and enrich CLI output with manifest or lockfile metadata when available

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
