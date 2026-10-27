# conan

ReqPack Lua wrapper for Conan v2 using Conan local cache as shared cache.

## What it manages

- remote recipe and package downloads into Conan cache
- local recipe export into Conan cache
- cache-local recipe and package removal
- cache and remote catalog queries

## Package forms

- `zlib/1.3.1`
- `openssl/3.3.1@user/channel`
- `zlib/1.3.1#recipe_revision`
- `zlib/1.3.1#recipe_revision:package_id#package_revision`

## Notes

- shared cache lives in `~/.conan2`
- `install()` means download into Conan cache, not project deployment
- `installLocal()` exports local recipe with `conan export`
- `outdated()` conservative/empty in v1
- plugin does not add/update/remove remotes or profiles

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
