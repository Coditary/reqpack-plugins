# x10build API

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Package forms

- `x10`
- `app:x10`

## Behavior summary

- installs X10 from official GitHub release tarballs or local source trees
- builds sources with `ant dist` inside `x10.dist`
- stores downloaded archives and extracted sources in shared cache root
- stores active install metadata under plugin data root
- `list()` returns active installed version only in v1
- `search()` returns canonical X10 package hit with latest version plus GitHub release metadata in v1
- `outdated()` compares active install against latest upstream GitHub release
