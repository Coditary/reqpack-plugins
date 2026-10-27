# clasp API

## Supported Request Flags

- global-ish: `cache-root=<dir>`, `user=<name>`, `project=<file>`, `auth=<file>`, `adc`
- install create: `title=<title>`, `type=<type>`, `parentId=<id>`, `rootDir=<dir>`
- install clone: `versionNumber=<n>`, `rootDir=<dir>`
- installLocal / update: `force`
- update: `pull`, `push`, `version-description=<text>`, `deployment-description=<text>`, `deploymentId=<id>`, `versionNumber=<n>`
- remove: `delete-script`, `all`

## Action Mapping

- `install(script:ID)`: `clasp clone-script ...`
- `install(project:/path + create flags)`: `clasp create-script ...`
- `installLocal(/path)`: `cd /path && clasp push`
- `remove(deployment:ID)`: `clasp delete-deployment ID`
- `remove(project:/path, delete-script)`: `cd /path && clasp delete-script --force`
- `update(project:/path)`: `cd /path && clasp push`
- `update(..., pull)`: `cd /path && clasp pull` then push/deploy/version as requested

## Returned Data

Items are script-centric. Common fields:

- `name`
- `packageId`
- `version`
- `latestVersion`
- `homepage`
- `packageType`
- `installed`
- `status`
- `extraFields.scriptId`
- `extraFields.projectPath`
- `extraFields.deployments`
- `extraFields.versions`
- `extraFields.fileStatus`
- `extraFields.auth`

## Cache Files

- `auth.json`
- `scripts.json`
- `scripts/<script-id>/deployments.json`
- `scripts/<script-id>/versions.json`
- `projects/<hash>/project.json`
- `projects/<hash>/status.json`
