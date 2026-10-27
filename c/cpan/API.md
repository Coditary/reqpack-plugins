# CPAN Wrapper API

Short operator-facing reference for `cpan` wrapper.

## Shared Environment

All commands run with one plugin-owned CPAN and local::lib environment:

```text
.reqpack-data/cpan-home
.reqpack-data/perl5
```

Common env:

```text
HOME=<data-root>/home
AUTOMATED_TESTING=1
NONINTERACTIVE_TESTING=1
PERL_MM_USE_DEFAULT=1
PERL_CPAN_HOME=<cpan-home>
PERL_MM_OPT=INSTALL_BASE=<perl5>
PERL_MB_OPT=--install_base <perl5>
PERL5LIB=<perl5>/lib/perl5
```

## Actions

- `install(context, packages)`:
  - uses `cpan -i`
  - supports `mirror=`, `prefer-mirror`, `force`, `notest`, `sudo`, `version`
- `installLocal(context, path)`:
  - supports local directories and common CPAN archives
- `remove(context, packages)`:
  - unsupported; fails clearly
- `update(context, packages)`:
  - uses `cpan -u <module>`
  - supports same mirror/test/sudo flags as install
- `list(context)`:
  - parses `cpan -l`
- `outdated(context)`:
  - parses `cpan -O`
- `search(context, prompt)`:
  - best-effort exact detail lookup via `cpan -D`
- `info(context, name)`:
  - parses `cpan -D`

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
