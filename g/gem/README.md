# reqpack-plugin-gem

ReqPack Lua wrapper plugin for RubyGems `gem`.

Plugin uses plugin-owned shared RubyGems environment.
It does not install into user default `GEM_HOME`.

## Package Form

- `rake`
- `name = "rake", version = "13.4.2"`

Supported package flags in `package.flags`:

- `source=https://rubygems.org`
- `prerelease`
- `ignore-dependencies`

## Supported Actions

- install remote gems into shared plugin-owned `GEM_HOME`
- install local `.gem` artifacts
- remove managed gems from shared plugin-owned `GEM_HOME`
- update managed gems
- list managed installed gems
- show managed outdated gems
- search remote RubyGems index
- inspect one gem via local or remote gemspec lookup

## Runtime Paths

- install root: `.reqpack-data/gem-home/`
- executables: `.reqpack-data/gem-bin/`
- spec cache: `.reqpack-data/spec-cache/`

## v1 Notes

- wrapper manages only plugin-owned install root
- host `.gemrc` intentionally ignored
- remove does not purge cached downloads from spec cache

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
