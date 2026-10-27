# poetry Plugin API Notes

## Commands Used

- install: `poetry add --no-interaction`
- local install: `poetry add --no-interaction <path>`
- remove: `poetry remove --no-interaction`
- update: `poetry update --no-interaction`
- list: `poetry show --top-level --format json`
- outdated: `poetry show --top-level --latest --outdated --format json`
- search: `poetry search`
- info: shared query project + `poetry add --lock` + `poetry show --format json <package>`

## Supported Request Flags

- location: `dir=<path>`
- query cache root: `cache-root=<path>`
- add/remove groups: `group=<name>`, `dev`
- add/install selectors: `optional`, `editable`, `allow-prereleases`, `lock`, `latest`
- add value selectors: `extras=<name>`, `python=<constraint>`, `platform=<platform>`, `markers=<expr>`, `source=<name>`
- show/update selectors: `with=<groups>`, `without=<groups>`, `only=<groups>`, `all-groups`, `all-extras`, `no-root`, `no-directory`, `sync`

## Behavior

- `install()` uses one `poetry add` command per package
- `list()` and `outdated()` return top-level dependencies only
- `search()` uses shared query project so Poetry has stable context
- `info()` resolves target package inside shared query project and returns best-effort metadata

## Store Hints

When available, returned items include `extraFields` such as:

- `installedStatus`
- `cacheDir`
- `virtualEnvPath`
- `groups`
- `dependencies`
- `files`
- `sourceType`
- `sourceUrl`
