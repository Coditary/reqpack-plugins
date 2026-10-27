# API

## Plugin Name

- system id: `jbang`
- display name: `JBang`
- version: `0.1.0`

## Actions

### install

Runs `jbang app install` once per package.

Supported `package.flags`:

- `name=<command>`
- `java=<version>`
- `main=<class>`
- `catalog=<path>`
- `source-type=<type>`
- `native`
- `preview`
- `interactive`
- `no-build`
- `fresh`
- `offline`
- `insecure`

### installLocal

Runs `jbang app install <path>` for local scripts or jars.

### remove

Runs `jbang app uninstall <command>`.

### update

Runs reinstall-style updates with `jbang app install --force`.
For installed apps, wrapper script metadata is reused when available.

### list

Lists installed command names from `jbang app list --format json` and enriches with parsed wrapper metadata.

### outdated

Returns empty list.

### search

Searches aliases available from `jbang alias list --format json`.

### info

Returns installed command info or alias info.

## Important Fields

- `extraFields.commandName`
- `extraFields.installRef`
- `extraFields.scriptRef`
- `extraFields.jbangHome`
- `extraFields.jbangCacheDir`
- `extraFields.jbangBinDir`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
