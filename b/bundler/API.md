# bundler API

## Actions

- `install`: `bundle add <gem>` per requested gem
- `installLocal`: `bundle add <gem> --path <dir>` for local gem project or `.gemspec`
- `remove`: `bundle remove <gem...> --install`
- `update`: `bundle update <gem...>` or `bundle update --all`
- `list`: parse `Gemfile.lock`
- `outdated`: `bundle outdated --parseable`
- `search`: `gem search --remote --details`
- `info`: merge project lock/query lock with `gem specification --remote --yaml`

## Supported Flags

Context or package flags:

- `dir=<path>`: project directory containing `Gemfile`
- `cache-root=<path>`: shared query/cache root override
- `group=<name>`: `bundle add --group <name>` or `bundle update --group <name>`
- `source=<name-or-url>`: `bundle add --source <value>`
- `skip-install`: `bundle add --skip-install`
- `strict`: `bundle add --strict`, `bundle update --strict`, `bundle outdated --strict`
- `optimistic`: `bundle add --optimistic`
- `local`: `bundle update --local`, `bundle outdated --local`
- `patch`, `minor`, `major`, `pre`, `conservative`: update/outdated flags
- `path=<dir>`, `git=<url>`, `github=<org/repo>`, `branch=<name>`, `ref=<sha>`, `glob=<pattern>`: forwarded to `bundle add`

## Returned Fields

Common package fields:

- `name`
- `packageId`
- `version`
- `latestVersion`
- `description`
- `homepage`
- `license`
- `dependencies`
- `installed`
- `status`
- `packageType = "gem"`

Useful `extraFields` include:

- `requestedConstraint`
- `directDependency`
- `sourceType`
- `sourceRemote`
- `sourceRevision`
- `platforms`
- `bundlerVersion`
- `projectDir`
- `gemPath`
- `registry`

## Notes

- `list()` and installed `info()` are lockfile-based first
- `outdated()` treats Bundler exit code `1` as success with outdated results
- `search()` and remote `info()` share one cache root with Bundler user cache and RubyGems spec cache
- `installLocal()` resolves gem name from local `.gemspec` filename

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
