# pnpm Plugin API Notes

## Commands Used

- install: `pnpm add`
- local install: `pnpm add <path>`
- remove: `pnpm remove`
- update: `pnpm update`
- list: `pnpm list --json --depth 0`
- outdated: `pnpm outdated --format json`
- search: `pnpm search --json`
- info: `pnpm view --json`

## Supported Request Flags

- scope: `global`, `dir=<path>`, `global-dir=<path>`, `store-dir=<path>`
- install class: `save-dev`, `save-optional`, `save-peer`, `save-prod`, `save-exact`
- update: `latest`, `dev`, `prod`, `no-optional`
- execution: `ignore-scripts`, `offline`, `prefer-offline`, `workspace`, `workspace-root`

## Behavior

- `list()` returns direct installed deps from project or global scope
- `outdated()` returns packages from pnpm outdated JSON
- `search()` uses pnpm npm-registry-backed JSON output
- `info()` forwards raw package spec to `pnpm view --json`

## Store Hints

When available, returned items include `extraFields` such as:

- `dependencyType`
- `resolved`
- `installPath`
- `storePath`
- `globalRoot`
- `registry`
