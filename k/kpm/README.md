# kpm

ReqPack wrapper for Kotlin Package Manager.

Package forms:

- `group:artifact:version`
- `group:artifact` with explicit ReqPack package version

Supported actions:

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

Runtime and cache paths:

- current project: `./kpm.json`, `./kpm-lock.json`
- upstream shared store: `~/.kpm/store`
- upstream gc roots: `~/.kpm/gcroots`
- upstream profiles: `~/.kpm/profiles`
- wrapper cache: `.reqpack-data/kpm/`
- bootstrapped launcher: `~/.local/share/reqpack/kpm/`

Major v1 limits:

- upstream `kpm` has no native `search`, `info`, `list`, `remove`, or `update`; wrapper uses Maven Central for remote metadata and manifest rewrites for remove/update
- no support for classifiers, packaging suffixes, or version ranges
- local installs support only external `kpm.json` or directory containing `kpm.json`

Test:

`rqp test-plugin --plugin ./run.lua --preset core`
