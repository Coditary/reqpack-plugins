# odpkg API

## Flags

- `cwd=<path>`: project root containing `odpkg.toml`
- `cache-home=<path>`: override cache root for shared odpkg registry cache
- `registry`: interpret install target as registry slug
- `refresh`: refresh registry for `list --registry`, `search`, and registry `info`
- `alias=<name>`: optional alias for single-package install when request does not carry one

## Behavior

- `install`: runs `odpkg add ...` per request, then one `odpkg install`
- `remove`: runs `odpkg remove <alias>` per request
- `update`: runs `odpkg update` once per project
- `list`: returns project deps by default, registry rows when `registry` flag is set or no project exists
- `search`: runs `odpkg search <query>`
- `info`: returns local project dependency info when project alias exists, otherwise exact registry slug info from shared cache
- `outdated`: returns `[]`

## Output notes

- project records are enriched from `odpkg.lock` when present
- registry search/list expose slug, repo URL, and status
- registry info can include `displayName`, `description`, `license`, `status`, and `repositoryUrl` when present in cached JSON
