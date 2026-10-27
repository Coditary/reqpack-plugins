# reqpack-plugin-docker

ReqPack wrapper plugin for Docker images.

Plugin treats Docker images as packages and uses Docker image store as shared cache.
It does not create second plugin-managed cache in v1.

## Package Forms

- `nginx`
- `nginx:latest`
- `ghcr.io/coditary/reqpack:v1.0.15`
- `alpine@sha256:...`

Optional request flags:

- `platform=linux/amd64`

## Supported Operations

- `install`: `docker pull`
- `installLocal`: `docker load --input`
- `remove`: `docker image rm`
- `update`: `docker pull`
- `list`: local image store via `docker image ls`
- `search`: Docker Hub search via `docker search`
- `info`: local `docker image inspect`, then remote `docker manifest inspect --verbose`
- `outdated`: compares local image digest to remote manifest digest when platform match is available
- `resolvePackage`

## Shared Cache

- installs, local loads, list, local info, and outdated checks all use Docker image store
- remote-only queries use Docker registry lookups through Docker CLI
- plugin does not manage daemon blob storage directly

## Important Notes

- v1 manages images only, not containers, builds, login, or push flows
- `update` with empty package list is a no-op because Docker has no safe all-images upgrade command
- digest-pinned refs are treated as immutable and are not considered upgradeable

## Testing

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
