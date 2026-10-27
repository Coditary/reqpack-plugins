# io

ReqPack wrapper for Io ecosystem package management via `eerie`.

- plugin id: `io`
- wrapped CLI: `eerie`
- package forms: Git URLs, archive URLs, local paths, `owner/repo`
- shared state root: ReqPack data root + `/io/eerie`
- limitation: no true remote registry search and no deterministic outdated query in v1

Test:

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
