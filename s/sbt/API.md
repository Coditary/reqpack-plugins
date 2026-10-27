# sbt API

## Coordinates

Accepted package coordinates:

- `group:artifact`
- `group:artifact:version`

Canonical package name in results:

- `group:artifact`

Full coordinate field:

- `group:artifact:version`

## Flags

- `data-root=/path` override plugin state/cache root
- `limit=<n>` search result limit

## Action Notes

### install

- requires explicit version
- rewrites tracked state and runs sbt `update`

### remove

- matches by `group:artifact`
- rewrites tracked state and synthetic project

### update

- requires explicit version
- rewrites tracked state and runs sbt `update`

### list

- returns tracked dependencies
- tries `show update` to expose selected version when possible

### outdated

- returns empty list in v0.1.0

### search

- queries Maven Central Solr API

### info

- exact Maven Central lookup for latest or requested version

### installLocal

- unsupported for this plugin
