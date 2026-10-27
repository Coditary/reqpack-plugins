# poetry

ReqPack Lua wrapper plugin for `poetry`.

## Package Forms

- registry package: `requests`
- exact version: `requests==2.32.3`
- Poetry constraint: `requests@^2.32`
- extras: `requests[socks]`
- local folder, wheel, or source archive in `installLocal()`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime / Cache Paths

- shared plugin root: `~/.cache/reqpack/poetry`
- Poetry cache env root: `~/.cache/reqpack/poetry/cache`
- Poetry config env root: `~/.cache/reqpack/poetry/config`
- Poetry data env root: `~/.cache/reqpack/poetry/data`
- shared query project: `~/.cache/reqpack/poetry/query-project`

Plugin reuses one shared query/cache root for Poetry-backed metadata lookups.

## Examples

Install latest package into docs group with extras:

```text
requests[socks]
flags: group=docs, extras=socks, latest
```

Install exact package version in project dir:

```text
requests==2.32.3
flags: dir=./my-project
```

Install local editable package:

```text
localPath: ../libs/demo-lib
flags: dir=./my-project, editable
```

Update only dev dependencies:

```text
flags: dir=./my-project, dev
```

Read package metadata through shared query cache:

```text
prompt: requests
flags: cache-root=~/.cache/reqpack/poetry
```

`info()` returns best-effort metadata merged from `poetry show --format json` and `poetry.lock`, including groups, dependency constraints, files, Python version constraints, homepage, license, and source details when available.

## v1 Limits

- project-oriented manager: most actions need Poetry project directory via current cwd or `dir=<path>` flag
- `search()` depends on Poetry search support of configured sources
- `info()` resolves package through shared query project instead of direct remote metadata API
- no publish/build/source-management wrappers

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
