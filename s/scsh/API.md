# scsh Plugin API

## Actions

- `install(context, packages)`
: runs `scsh-install-pkg` once per requested package token

- `installLocal(context, path)`
: runs `scsh-install-pkg` for local package directory

- `remove(context, packages)`
: removes only tracked packages inside ReqPack-managed paths

- `update(context, packages)`
: replays tracked install source through `scsh-install-pkg`

- `list(context)`
: returns tracked installed packages from `installed.tsv`

- `outdated(context)`
: compares tracked versions against cached catalog TSV when available

- `search(context, prompt)`
: searches cached catalog TSV by substring

- `info(context, name)`
: merges tracked installed state with cached catalog metadata

## Catalog TSV schema

```text
name<TAB>version<TAB>summary<TAB>source<TAB>homepage<TAB>license
```

## Installed TSV schema

```text
name<TAB>version<TAB>destDir<TAB>sourceKind<TAB>sourceValue<TAB>installedAt<TAB>catalogSource
```
