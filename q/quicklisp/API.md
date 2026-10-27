# API

## Behavior Summary

- `install()`: bootstraps shared Quicklisp home if needed, then runs `ql:quickload` for requested systems
- `installLocal()`: copies local project directory into shared Quicklisp `local-projects/`, then runs `ql:register-local-projects`
- `remove()`: removes local project directories for local systems or runs `ql:uninstall` for dist-backed systems
- `update()`: runs `ql:update-dist "quicklisp" :prompt nil`, then optionally `ql:quickload`s requested systems
- `list()`: returns local systems plus installed systems from enabled Quicklisp dists
- `outdated()`: reports installed systems when Quicklisp dist has newer available version
- `search()`: uses `ql:system-apropos-list`
- `info()`: returns local-system info first, otherwise exact Quicklisp system metadata

## Supported Flags

- `data-root=/path/to/root`: override ReqPack-managed plugin data root

## Notes

- plugin never edits Lisp init files
- shared cache is Quicklisp home itself; no second package cache is maintained
- machine-readable rows come from generated batch Lisp scripts executed with `sbcl`
