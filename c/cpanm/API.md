# CPANM Wrapper API

Short operator-facing reference for `cpanm` wrapper.

## Shared Environment

All commands run with one plugin-owned cpanminus and local::lib environment:

```text
.reqpack-data/cpanm-home
.reqpack-data/perl5
```

Common env:

```text
PERL_CPANM_HOME=<cpanm-home>
PERL_MM_OPT=INSTALL_BASE=<perl5>
PERL_MB_OPT=--install_base <perl5>
PERL5LIB=<perl5>/lib/perl5
PATH=<perl5>/bin:$PATH
AUTOMATED_TESTING=1
NONINTERACTIVE_TESTING=1
PERL_MM_USE_DEFAULT=1
```

## Actions

- `install(context, packages)`:
  - uses `cpanm`
  - supports `mirror=`, `from=`, `mirror-only`, `force`, `notest`, `sudo`, `dev`, `self-contained`, `exclude-vendor`, `cascade-search`, `skip-installed`, `skip-satisfied`, `version`, `version-range`
- `installLocal(context, path)`:
  - supports local dirs and common archives
- `remove(context, packages)`:
  - uses `cpanm --uninstall`
- `update(context, packages)`:
  - uses `cpanm --reinstall`
  - supports same install flags
- `list(context)`:
  - uses isolated `perl` plus `ExtUtils::Installed`
- `outdated(context)`:
  - returns empty list intentionally
- `search(context, prompt)`:
  - exact lookup via `cpanm --info`
- `info(context, name)`:
  - combines `cpanm --info` with local installed version probe

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
