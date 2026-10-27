# XBPS Smoke Checks

Run these on Void Linux host or disposable Void container with `xbps-install`, `xbps-remove`, `xbps-query`, and `xbps-rindex` available.

## Preconditions

- disposable rootfs, VM, or container preferred
- root or sudo access for install/remove/update paths
- ReqPack runtime with this plugin available

## Read-Only Checks

```bash
rqp list xbps
rqp search xbps ripgrep
rqp info xbps xbps
rqp outdated xbps
```

Expected:

- `list` returns installed packages from pkgdb
- `search` returns repository matches
- `info` returns installed package metadata or remote fallback
- `outdated` returns zero or more upgradable packages

## Repository Override Check

```bash
rqp search xbps hello --flags repository=https://repo-default.voidlinux.org/current memory-sync
```

Expected:

- plugin passes explicit repository
- query still returns sensible remote data

## Local Artifact Check

Use small local `.xbps` package already present on host.

```bash
rqp install xbps --local /path/to/demo-1.0_1.x86_64.xbps
```

Expected:

- plugin stages artifact under shared cache root
- plugin indexes temp repo with `xbps-rindex -a`
- install succeeds through native `xbps-install --repository=<temp-repo>`

## Managed Package Check

Choose harmless package in disposable environment.

```bash
rqp install xbps hello
rqp info xbps hello
rqp remove xbps hello
```

Expected:

- install succeeds through `xbps-install`
- info returns installed version
- remove succeeds through `xbps-remove`

## Explicit Dangerous Remove Check

Only in disposable environment:

```bash
rqp remove xbps hello --flags recursive force-remove
```

Expected:

- recursive removal only happens when explicitly requested

## Update Check

If host has upgradable package:

```bash
rqp outdated xbps
rqp update xbps <package-name>
```

Expected:

- outdated lists package before update
- update runs `xbps-install -u`

## Hermetic Tests

```bash
rqp test-plugin --plugin ./run.lua --preset core
lua ./.reqpack-test/extra/resolve-package-smoke.lua
lua ./.reqpack-test/extra/get-missing-packages-smoke.lua
```
