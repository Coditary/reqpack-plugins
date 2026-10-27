# API

## Flags

- `data-root=<path>`
- `repo=<url>` or `repos=<url>`
- `source=cran|version|bioc|github|gitlab|bitbucket|git|svn|url|dev`
- `ref=<git-ref>`
- `subdir=<path>`
- `host=<host>`
- `username=<owner>`
- `url=<remote-url>`
- `mirror=<bioc-mirror>`
- `dependencies=true|false|soft|hard`
- `upgrade=default|always|never`
- `force=true|false`
- `build=true|false`
- `build-manual=true|false`
- `build-vignettes=true|false`
- `type=source|binary|both`

## Behavior

- installs run one package at a time so package-specific flags stay isolated
- helper package `devtools` installs into shared helper library
- managed packages install into shared managed library
- remote installs expose DESCRIPTION `Remote*` fields through `extraFields`
- query paths degrade to empty results with warnings when `Rscript` unavailable

## Update Rules

- CRAN-like installs use `devtools::update_packages()`
- GitHub/GitLab/Bitbucket/git/svn/url/dev installs reconstruct update call from installed `Remote*` metadata
- local installs fail on update because source path cannot be recovered honestly
