# opam API

## Flags

- `root=<path>`: use specific `OPAMROOT`
- `data-root=<path>`: use `<path>/opam-root`
- `switch=<name>`: use specific switch
- `with-test`
- `with-doc`
- `with-dev-setup`
- `assume-depexts`
- `no-depexts`
- `best-effort`
- `working-dir`
- `locked`
- `keep-build-dir`
- `reuse-build-dir`
- `inplace-build`
- `ignore-pin-depends`
- `criteria=<value>`
- `jobs=<n>`
- package-only: `constraint=<raw-opam-constraint>`

## Notes

- package install/update/remove operate on selected switch
- `outdated` refreshes repositories with `opam update` before checks
- `search` and `info` use opam metadata fields directly
- shared cache behavior depends on reusing same root across commands
