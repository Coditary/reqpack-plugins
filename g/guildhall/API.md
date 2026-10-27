# guildhall API

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Flags

- `repo=<uri>`
- `no-depends`

## Behavior summary

- all commands run with isolated Guildhall home under ReqPack cache
- remote queries and installs require repo flags or `REQPACK_GUILDHALL_REPO`
- local installs use `guild show-bundle` and `guild install --bundle`
- `update` with named packages reuses `guild install` because Guildhall upgrades installed package on install
- `search` and `outdated` are derived from other Guildhall commands because upstream has no dedicated command
