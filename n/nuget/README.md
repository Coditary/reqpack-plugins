# nuget

ReqPack Lua wrapper for NuGet CLI using one ReqPack-managed shared cache.

## What it manages

- package downloads into ReqPack cache directory
- local `.nupkg` staging through folder-based NuGet feed
- cache-local package removal
- cache and remote catalog queries

## Package forms

- `Newtonsoft.Json`
- `Newtonsoft.Json@13.0.3`
- local `.nupkg` path through `installLocal()`

## Notes

- shared cache default lives in `n/nuget/.reqpack-data/nuget-cache/`
- installed payloads live under `.reqpack-data/nuget-cache/packages/`
- local artifact staging feed lives under `.reqpack-data/nuget-cache/local-feed/`
- `install()` downloads package contents to cache; it does not modify project references
- `remove()` only deletes ReqPack-managed cache folders, never global NuGet caches
- `outdated()` returns empty in v1 because NuGet CLI has no honest cache-wide outdated query for this wrapper model

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
