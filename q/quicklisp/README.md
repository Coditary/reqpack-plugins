# Quicklisp ReqPack Plugin

ReqPack wrapper for Quicklisp Common Lisp systems.

## Package Forms

- remote system latest: `quicklisp:alexandria`
- remote system explicit version: `quicklisp:alexandria@<ignored-in-v1>`
- local project via `installLocal`: path to extracted project directory with one or more `.asd` files

## Supported Actions

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

## Runtime And Cache Paths

- shared plugin root: `<reqpack-data-root>/quicklisp`
- shared Quicklisp home: `<reqpack-data-root>/quicklisp/home`
- bootstrap cache: `<reqpack-data-root>/quicklisp/bootstrap`
- generated batch Lisp scripts: `<reqpack-data-root>/quicklisp/tmp`
- shared local projects: `<reqpack-data-root>/quicklisp/home/local-projects`

## Major v1 Limitations

- v1 uses `sbcl` as Lisp runner
- Quicklisp version pinning is not supported per package; current dist snapshot wins
- `update()` is dist-first; package-targeted update still updates Quicklisp dist globally first
- `remove()` follows upstream Quicklisp release semantics; sibling systems from same release may disappear too
- `installLocal()` supports extracted project directories only, not raw archives

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
