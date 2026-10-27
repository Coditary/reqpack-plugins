# clasp

ReqPack Lua wrapper for `clasp`, Google Apps Script CLI.

## Package Forms

- `script:<scriptId-or-url>`
- `project:<path>`
- `deployment:<deploymentId>`

Plain values default to `script:<value>` for lookup and clone flows.

## Supported Actions

- `install`: clone remote script or create new script
- `installLocal`: push local project already configured with `.clasp.json`
- `remove`: delete deployment, or delete script when explicit `delete-script` flag set
- `update`: pull/push current project and optionally create version/deployment
- `list`: current local project plus cached/remote script list
- `outdated`: empty list
- `search`: filter script list by id, name, url, or local path
- `info`: enrich one script with auth, versions, deployments, and file status

## Runtime And Cache Paths

- auth file read by clasp: `~/.clasprc.json`
- local project config: `.clasp.json`
- shared cache default: `c/clasp/.reqpack-data/cache/`
- shared cache override: request flag `cache-root=<dir>` -> `<dir>/clasp/`

## Major v1 Limitations

- no automated `clasp login`
- no watch mode or tail-logs wrapper
- no reliable outdated concept in clasp ecosystem, so `outdated()` returns empty
- whole-script deletion requires explicit `delete-script` flag

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
