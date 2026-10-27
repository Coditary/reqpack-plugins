# vfp-pm

ReqPack Lua wrapper for Visual FoxPro packages using FoxGet-compatible metadata and a configurable VFP bridge.

## What it manages

- FoxGet-style package catalog exported to ReqPack cache as TSV
- project-local installed packages from `Packages/packages.xml`
- install, remove, and update flows through user-provided VFP bridge command

## Package forms

- `SomePackage`
- `SomePackage@1.2.3`
- local installer `.prg` path through `installLocal()`

## Notes

- shared cache root default: `~/.cache/reqpack/vfp-pm/`
- default catalog snapshot path: `~/.cache/reqpack/vfp-pm/catalog/packages.tsv`
- generated bridge scripts/results live under `~/.cache/reqpack/vfp-pm/bridge/`
- installed package state stays project-local at `<project>/Packages/packages.xml`
- plugin id is `vfp-pm`, but implementation is based on documented FoxGet behavior because no public standalone `vfp-pm` CLI could be verified
- mutation actions require `VFP_PM_BRIDGE` or request field `bridgeCommand`
- query actions can use `catalogPath`, `catalog-url=<url>`, or cached TSV snapshot

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
