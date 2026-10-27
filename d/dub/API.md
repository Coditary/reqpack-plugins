# API

Package forms:

- `{ name = "vibe-d", version = "0.9.5", packageType = "package" }`
- `{ name = "vibe-d", version = "0.9.5", packageType = "dependency" }`

Supported actions:

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `outdated`
- `search`
- `info`

Notes:

- missing `packageType` defaults to `package`
- `installLocal()` writes local path dependency entry into plugin-owned synthetic `dub.json`
- `outdated()` reports only synthetic dependency entries with resolvable remote latest versions
