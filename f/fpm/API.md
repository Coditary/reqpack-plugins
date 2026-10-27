# fpm Plugin API

## Supported Actions

- `install(context, packages)`
- `installLocal(context, path)`
- `remove(context, packages)`
- `update(context, packages)`
- `list(context)`
- `outdated(context)`
- `search(context, prompt)`
- `info(context, name)`
- `resolvePackage(context, package)`

## Command Mapping

Registry dependency cache refresh:

```text
fpm update --fetch-only
```

Local project install:

```text
fpm install --profile release
```

## Package Forms

Registry dependency:

```lua
{ name = "stdlib", version = "0.1.0", namespace = "fortran-lang" }
```

Namespace fallback:

```lua
{ name = "stdlib", extraFields = { namespace = "fortran-lang" } }
```

Local install target:

```text
/path/to/fpm-project
```

## Query Behavior

- `list()` returns plugin-managed desired dependency state from synthetic manifest
- `outdated()` only reports pinned versions older than registry latest
- `search()` and `info()` use official fpm registry index
- `resolvePackage()` resolves latest metadata and namespace when possible

## Important v1 Limits

- no global package listing from real fpm cache
- no stable purl metadata emitted
- no purge of downloaded registry cache content on remove
- ambiguous namespace requires explicit request field when registry data is insufficient
