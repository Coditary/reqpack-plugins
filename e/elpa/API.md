# ELPA Plugin API

Supported ReqPack actions:

- install named packages through `package-install` / `package-upgrade`
- install local `.el` or `.tar` through `package-install-file`
- remove installed packages through `package-delete`
- update named packages or all outdated installed packages
- list installed packages
- list outdated installed packages
- search available packages across GNU ELPA and NonGNU ELPA
- show exact package info

Package identity:

- package `name` is Emacs package symbol string such as `use-package`

Runtime details:

- package operations run in batch `emacs`
- plugin pins `package-user-dir` to ReqPack-owned shared root
- archive source set is fixed to GNU ELPA + NonGNU ELPA in v1

Local install:

- supported extensions: `.el`, `.tar`
- unsupported local artifact types fail explicitly

Security metadata summary:

- role: `package-manager`
- capabilities: `exec`, `network`
- privilege: `user`
- write scope: `~/.local/share/reqpack/elpa`

Test command:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
