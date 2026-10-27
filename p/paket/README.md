# paket

ReqPack Lua wrapper for Paket using one ReqPack-managed shared workspace.

## What it manages

- shared Paket workspace under plugin `.reqpack-data`
- package install, remove, update, list, outdated, search, and info flows through `dotnet paket`
- local `.nupkg` staging through workspace local feed

## Package forms

- `Newtonsoft.Json`
- `Newtonsoft.Json@13.0.3`
- local `.nupkg` path through `installLocal()`

## Notes

- shared workspace default lives in `p/paket/.reqpack-data/workspace/`
- shared `paket.dependencies` and `paket.lock` live in that workspace
- staged local artifacts live under `.reqpack-data/workspace/local-feed/`
- local archive cache lives under `.reqpack-data/workspace/local-cache/`
- machine cache override lives under `.reqpack-data/workspace/machine-cache/`
- `install()` mutates ReqPack-managed Paket workspace, not arbitrary caller repositories
- wrapper requires `dotnet`; Paket tool itself must already be available to `dotnet paket`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
