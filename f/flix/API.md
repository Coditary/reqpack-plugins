# flix API

## Identity

- plugin id: `flix`
- package id: `owner/repo`
- dependency id written to Flix manifest: `github:owner/repo`

## Supported Request Fields

- `name`: package id or repo name
- `packageId`: preferred package id `owner/repo`
- `version`: optional SemVer tag
- `security`: optional Flix dependency security context
- `extraFields.flix.security`: alternate security field
- `localPath` / `path`: local project path for `installLocal`

## Action Mapping

- `install`: writes dependency entries into synthetic `flix.toml`, ensures minimal source file, runs `flix check --yes`
- `installLocal`: runs `flix build-pkg` inside local project path
- `remove`: removes dependency entries from synthetic `flix.toml`
- `update`: rewrites tracked versions and runs `flix check --yes`
- `list`: returns synthetic manifest entries enriched with GitHub metadata
- `outdated`: compares tracked versions to latest GitHub releases
- `search`: GitHub repository search heuristic for Flix packages
- `info`: GitHub repo details plus latest release version

## Notes

- shared cache lives in one plugin-owned synthetic project
- Flix itself manages transitive Flix, Maven, and jar downloads under `lib/`
- GitHub token can be provided through environment or request flags if needed by host
