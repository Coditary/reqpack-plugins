# API

## Actions

### install

Runs `deft install <pkg>` per requested package.

### installLocal

Unsupported. Returns clear error.

### remove

Removes installed package cache directories from resolved `_packages` root.

### update

- no packages: `deft update`
- with packages: `deft install <pkg>` per package, then `deft update`

### list

Parses `deft list` and enriches with installed `dylan-package.json` metadata.

### outdated

Uses `deft list` outdated marker and installed/latest versions.

### search

Uses `deft list --all` and local ranking.

### info

Combines `deft list --all` with local installed metadata.
