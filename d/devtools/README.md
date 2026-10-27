# devtools ReqPack Plugin

ReqPack wrapper for R packages installed through `devtools` and `remotes`.

## Package Forms

- CRAN latest: `jsonlite`
- CRAN versioned: `jsonlite` with `version=1.8.9`
- GitHub: `r-lib/cli` with `source=github`
- GitLab: `group/pkg` with `source=gitlab`
- Bitbucket: `workspace/pkg` with `source=bitbucket`
- git: URL in package name or `url=` with `source=git`
- svn: URL in package name or `url=` with `source=svn`
- url: archive URL in package name or `url=` with `source=url`
- Bioconductor: package name with `source=bioc`
- dev version: package name with `source=dev`

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Important Runtime Paths

- managed library: `<data-root>/library`
- helper library: `<data-root>/helper-library`
- cache: `<data-root>/cache`
- config: `<data-root>/config`
- temp: `<data-root>/tmp`

Default `data-root` lives under plugin `.reqpack-data` unless overridden with `data-root=<path>`.

## v1 Limits

- `search()` covers installed packages plus CRAN catalog matches
- `outdated()` reports CRAN-like installs only
- local-source updates are not supported without original path

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
