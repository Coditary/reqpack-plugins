# yarn

ReqPack Lua wrapper for Yarn Classic global npm packages.

## Package forms

- remote npm package: `eslint`
- remote npm package with version: `eslint@9.0.0`
- local package path via `installLocal()`

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime and cache paths

- global package dir: `yarn global dir`
- global bin dir: `yarn global bin`
- shared cache dir: `yarn cache dir`

## Major v1 limitations

- mutating actions target Yarn Classic (`1.x`) only
- remote search uses npm registry search API because Yarn Classic has no stable noninteractive remote search command
- plugin manages global packages only, not project dependencies

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
