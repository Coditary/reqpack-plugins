# Debian Smoke Checks

Run these on Debian or Ubuntu host with `dpkg`, `dpkg-query`, `apt`, `apt-get`, and `apt-cache` available.

## Preconditions

- test machine or container
- root or sudo access for install and remove actions
- ReqPack runtime with this plugin available

## Read-Only Checks

```bash
rqp list dpkg
rqp search dpkg curl
rqp info dpkg bash
rqp outdated dpkg
```

Expected:

- `list` returns installed packages
- `search` returns repository matches
- `info` returns installed or candidate metadata
- `outdated` returns zero or more upgradable packages

## Local Artifact Check

Use small local `.deb` file already present on host or download one into temp dir.

```bash
rqp install dpkg --local /path/to/package.deb
```

Expected:

- plugin runs `dpkg -i`
- ReqPack shows `installed` event and success

## Managed Package Check

Choose harmless package not yet installed in disposable environment.

```bash
rqp install dpkg sl
rqp info dpkg sl
rqp remove dpkg sl
```

Expected:

- install succeeds through `apt-get`
- info shows installed version
- remove succeeds through `dpkg -r`

## Update Check

If host has any upgradable package:

```bash
rqp outdated dpkg
rqp update dpkg <package-name>
```

Expected:

- `outdated` lists package before update
- `update` runs `apt-get install --only-upgrade`

## Hermetic Tests

```bash
rqp test-plugin --plugin . --preset core
rqp test-plugin --plugin . --cases ./.reqpack-test/failures
```
