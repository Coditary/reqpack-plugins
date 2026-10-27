# MiKTeX Plugin API Notes

## Commands Used

- `miktex packages update-package-database`
- `miktex packages install <package...>`
- `miktex packages remove <package...>`
- `miktex packages update <package...>`
- `miktex packages info --template '<template>' <package>`
- `miktex packages list --template '<template>'`
- `miktex packages check-update`

## Supported Flags

- `admin`
- `repository=<url-or-path>`

Flags can be supplied on request context or package objects. Request-level flags control emitted command line.

## Behavior Summary

- `list()` returns installed packages only
- `search()` uses shared cached catalog snapshot
- `info()` prefers direct CLI info, then cache fallback
- `outdated()` returns empty list when updates are unavailable or when upstream CLI does not provide package names
