# Gem Wrapper API

Short operator-facing reference for `gem` wrapper.

## Shared Environment

All commands run with one plugin-owned RubyGems environment:

```text
.reqpack-data/gem-home
.reqpack-data/gem-bin
.reqpack-data/spec-cache
```

Common env:

```text
GEM_HOME=<gem-home>
GEM_PATH=<gem-home>
GEM_SPEC_CACHE=<spec-cache>
GEMRC=/dev/null
```

## Actions

- `install(context, packages)`:
  - one `gem install` per requested gem
  - supports `version`, `source=`, `prerelease`, `ignore-dependencies`
- `installLocal(context, path)`:
  - supports local `.gem` files only
- `remove(context, packages)`:
  - uses `gem uninstall --all --executables --ignore-dependencies`
- `update(context, packages)`:
  - uses `gem update`
  - if explicit version supplied, uses install-to-version path
- `list(context)`:
  - parses `gem list --local --details`
- `outdated(context)`:
  - parses `gem outdated`
- `search(context, prompt)`:
  - parses `gem search --remote --details`
- `info(context, name)`:
  - local gemspec first, remote fallback

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
