# CRAN Plugin API Notes

Plugin id: `cran`

Supported actions:

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`
- `resolvePackage`

Request flags:

- `data-root=/path`
- `repo=https://cloud.r-project.org`
- `repos=https://cloud.r-project.org`
- `dependencies=true`
- `dependencies=false`

Returned package type:

- `r-package`

Important behavior:

- packages install into managed `R_LIBS_USER`, not host default library
- metadata cache and temp paths share same plugin state root
- `update` reinstalls latest suitable CRAN release for requested package names
- `installLocal` uses `install.packages(repos = NULL, ...)`

Test command:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
