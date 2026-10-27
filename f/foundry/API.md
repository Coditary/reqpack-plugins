# Foundry Plugin API

## Commands used

- `forge install --root <project> <dependency>`
- `forge remove --root <project> <dependency>`
- `forge update --root <project> [dependency]`
- `git -C <path> rev-parse --short HEAD`
- `git -C <path> config --get remote.origin.url`
- local scan of configured `libs` directories

## Behavior summary

- `install()` installs dependencies one-by-one so alias and ref flags stay package-specific
- `remove()` removes one dependency per command
- `update()` updates all dependencies or selected ones
- `list()` scans local Foundry dependency folders and enriches with local git metadata
- `search()` filters local records and can synthesize one installable dependency record from direct spec input
- `info()` returns installed metadata or synthetic direct-spec metadata
- `outdated()` returns empty list in v1
- `installLocal()` is unsupported

## Request notes

- use `name` or `packageId` for dependency spec
- install flags supported: `alias=<name>`, `tag=<tag>`, `branch=<branch>`, `rev=<sha>`, `shallow`, `no-git`, `commit`
- update flags supported: `force`, `recursive`
- project path override supported via `flags = { "dir=/path/to/project" }`
