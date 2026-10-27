# renv Plugin API

## Request semantics

Project-sensitive actions require `project=/abs/path`.

Supported flags:

- `project=/abs/path`
- `data-root=/abs/path`
- `repo=https://...`
- `snapshot=true|false`
- `lock=true|false`
- `dependencies=true|false|strong|most|all`
- `rebuild=true|false`

## Behavior summary

- installs and updates use `renv::install()` / `renv::update()`
- removals use `renv::remove()`
- shared cache controlled with `RENV_PATHS_*`
- plugin bootstraps `renv` when needed through helper library
- optional post-mutation snapshot keeps `renv.lock` aligned

## Query behavior

- `list`: installed packages in project library
- `outdated`: installed project packages with newer repo version
- `search`: remote repository search
- `info`: remote metadata, plus local project and lockfile metadata when `project=` exists
