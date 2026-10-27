# fan Plugin API

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

Remote install or upgrade:

```text
fanr install -y <query>
```

Installed pods query:

```text
fanr env '*'
```

Remote search and info:

```text
fanr query -n <count> <query>
```

Remove:

```text
fanr uninstall -y <query>
```

Local archive install:

```text
mkdir -p '<env.work>/lib/fan' && cp '<archive>.pod' '<env.work>/lib/fan/'
```

## Package Forms

Registry package:

```lua
{ name = "web", version = "1.0.79" }
```

Versionless request:

```lua
{ name = "web" }
```

Local install target:

```text
/path/to/example.pod
```

## Query Behavior

- `list()` reads installed pods from shared Fantom environment
- `outdated()` compares installed versions against latest repo version per pod
- `search()` returns latest matching version per pod by default
- `info()` returns latest version plus `extraFields.availableVersions`
- `resolvePackage()` resolves package name plus requested/latest version into one normalized item

## Important v1 Limits

- no publish wrapper behavior
- no directory-based local project install; only `.pod` archives
- no purl metadata in v1
