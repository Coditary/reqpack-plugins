# shards plugin API

## Command mapping

- `install` -> manifest edit + `shards install --no-color`
- `installLocal` -> manifest `path:` entry + `shards install --no-color`
- `remove` -> manifest edit + `shards install --no-color` + `shards prune --no-color`
- `update` -> optional manifest edit + `shards update ... --no-color`
- `list` -> `shards list --no-color`
- `outdated` -> `shards outdated --no-color`
- `search` -> cached `curl` fetch against `https://shards.info/search?query=...`
- `info` -> cached `curl` fetch against `https://shards.info/...` plus local manifest fallback

## Supported flags

- `dir=<path>` target Crystal project directory
- `path=<path>` alias for target directory
- `cache-root=<path>` override ReqPack shared cache root

## Supported package resolver flags

- `github=<owner/repo>`
- `gitlab=<group/project>`
- `bitbucket=<workspace/project>`
- `codeberg=<owner/project>`
- `git=<url>`
- `version=<constraint>`
- `branch=<name>`
- `tag=<name>`
- `commit=<sha>`

## Notes

- `shards` itself requires `shard.yml` in target directory
- plugin keeps `SHARDS_CACHE_PATH` shared under ReqPack cache
- plugin keeps `SHARDS_INSTALL_PATH` pointed at target `lib/`
- unsupported advanced YAML formatting may be normalized when manifest is rewritten
- remote `search` and most remote `info` data come from `shards.info`, so GitHub-backed packages get best metadata coverage
