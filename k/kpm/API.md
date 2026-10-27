# API

System id: `kpm`

Accepted package request:

- `name = "group:artifact:version"`
- or `name = "group:artifact"` plus `version = "..."`

Behavior summary:

- `install`: ensure manifest contains requested coordinates, bootstrap launcher if needed, run `kpm install`
- `installLocal`: merge dependencies from external `kpm.json`, then run `kpm install`
- `remove`: remove matching `group:artifact` entries from manifest and matching lock entries
- `update`: change manifest version for matching `group:artifact`, then run `kpm install`
- `list`: read local `kpm.json` and `kpm-lock.json`
- `outdated`: compare local tracked versions against Maven Central latest versions
- `search`: Maven Central search API
- `info`: Maven Central exact lookup plus local install enrichment

Important paths:

- launcher jar: `~/.local/share/reqpack/kpm/kpm.jar`
- launcher script: `~/.local/share/reqpack/kpm/bin/kpm`
- upstream store: `~/.kpm/store`
- wrapper cache root: `.reqpack-data/kpm`

Test:

`rqp test-plugin --plugin ./run.lua --preset core`
