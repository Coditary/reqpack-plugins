# renv ReqPack Plugin

ReqPack wrapper for `renv` project environments in R.

## Package forms

- `digest`
- `digest@0.6.32`
- `user/repo`
- `user/repo@ref`
- `user/repo:subdir`
- `bioc::Biobase`

## Supported actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Important paths

- shared renv state root: `<data-root>/shared/`
- shared cache: `<data-root>/shared/cache`
- shared helper library: `<data-root>/shared/helper-library`
- project lockfile: `<project>/renv.lock`
- project renv dir: `<project>/renv/`

## Important flags

- `project=/abs/path`
- `data-root=/abs/path`
- `repo=https://cloud.r-project.org`
- `snapshot=true`
- `lock=true`
- `dependencies=strong`
- `rebuild=true`

## v1 limitations

- project-scoped actions require `project=`
- `search` / projectless `info` query remote metadata only
- advanced renv workflows like profiles and checkout snapshots not wrapped yet

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
