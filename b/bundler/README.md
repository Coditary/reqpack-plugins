# bundler

ReqPack Lua wrapper plugin for Ruby `bundle`.

## Package Forms

- registry gem: `rack`
- exact version: `name = "rack", version = "~> 3.1"`
- grouped add: `flags: group=development`
- local gem project dir or `.gemspec` in `installLocal()`

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

- shared cache root: `~/.cache/reqpack/bundler`
- Bundler user cache: `~/.cache/reqpack/bundler/cache`
- Bundler user config: `~/.cache/reqpack/bundler/config`
- Bundler user plugin dir: `~/.cache/reqpack/bundler/plugin`
- shared query project: `~/.cache/reqpack/bundler/query-project`
- shared query vendor cache: `~/.cache/reqpack/bundler/query-vendor-cache`

Plugin reuses one shared Bundler/RubyGems cache root for `search()` and remote `info()` lookups.

## Examples

Install gem into project:

```text
name: rack
flags: dir=./my-app
```

Install gem with group and strict version declaration:

```text
name: rspec
version: ~> 3.13
flags: dir=./my-app, group=development,test, strict
```

Install local gem project:

```text
localPath: ../libs/my_gem
flags: dir=./my-app
```

Inspect remote metadata through shared query cache:

```text
prompt: rack
flags: cache-root=~/.cache/reqpack/bundler
```

## v1 Limits

- project-oriented manager: install/remove/update/list/outdated need project `Gemfile`
- `search()` uses RubyGems CLI because Bundler has no native remote search command
- `info()` merges Bundler query-lock data with RubyGems gemspec metadata
- raw built `.gem` files are not accepted by `installLocal()`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
