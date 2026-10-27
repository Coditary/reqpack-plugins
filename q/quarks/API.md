# quarks API

## Behavior

- wraps SuperCollider `Quarks` API through batch `sclang` scripts
- uses isolated HOME and `sclang` config under plugin data root
- keeps shared installed snapshot and directory cache for query fallback
- install/update/remove use real Quarks actions, not manual git emulation

## Request Mapping

- `name = "MathLib"` installs by Quarks directory name
- `name = "https://...git"` installs by git URL
- `version = "tags/1.0.0"` or SHA maps to Quarks refspec argument for `install`
- `installLocal(path)` installs local quark folder
- `remove` accepts installed quark name; path-like input resolves via tracked local path
- `flags` may include `data-root=/custom/root`

## Important Notes

- `list()` prefers live `Quarks.installed`, falls back to cached installed snapshot if live query fails
- `search()` and `info()` use Quarks directory cache plus installed snapshot
- `outdated()` fetches git metadata from installed quark working copies only when reliable
- local-path installs with no git remote are treated honestly and excluded from outdated detection

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
