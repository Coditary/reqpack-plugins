# rqp-plugin-dappy

ReqPack plugin for optional [Dappy](https://github.com/Coditary/Dappy) adapter and RSP target manifests.

Installed files land under `$XDG_CONFIG_HOME/dap/`:

- DAP adapters → `plugins/<id>/plugin.yaml` (and optional `attachment.yaml`)
- RSP targets → `targets/<id>/target.yaml`

`default-package-repositories.json` points at the [Coditary/dappy-registry](https://github.com/Coditary/dappy-registry) catalog (`packages.json`).

## Install plugin

```bash
rqp install .
```

## Usage

```bash
# Install Dappy CLI (ReqPack release index)
rqp install dappy-cli

# Or via the dappy catalog plugin
rqp install dappy dappy-cli

# Search optional Dappy plugins
rqp search dappy python

# Install Python debugpy adapter manifest
rqp install dappy python

# Install gdbserver RSP target manifest
rqp install dappy gdbserver

# List installed catalog packages
rqp list dappy
```

## Local registry (development)

Point `default-package-repositories.json` at a local `packages.json` or set a `file://` URL while developing the registry under `registry/dappy/`.
