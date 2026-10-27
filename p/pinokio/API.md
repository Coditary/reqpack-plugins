# pinokio API

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Package forms

- `app:pinokio`
- `script:<git-url-or-owner-repo>`
- `artifact:<artifact-id>`

## Behavior summary

- app install/update manages Pinokio desktop app payload
- `script:` clones or updates script repos in `~/pinokio/api`
- `artifact:` projects shared AICache artifact into Pinokio drive export area
- plugin metadata stored under `~/pinokio/reqpack`
- `remove` deletes runtime projection, not canonical AICache bytes
- `search()` only returns static `app:pinokio` hit in v1
- plugin does not run Pinokio scripts or launcher workflows
- `outdated()` returns empty list in v1
