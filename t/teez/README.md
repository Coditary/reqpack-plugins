# rqp-plugin-teez

ReqPack plugin for optional [teez](https://github.com/Coditary/teez-cli) **runner plugins** (e.g. vitest). Installs manifest + Lua into `~/.local/share/teez/plugins/`.

The **teez CLI** itself is installed with ReqPack from [teez-cli releases](https://github.com/Coditary/teez-cli/releases), not via `rqp install teez …`.

`default-package-repositories.json` points at the [Coditary/teez-registry](https://github.com/Coditary/teez-registry) catalog (`packages.json`).

## Install plugin

From this directory:

```bash
rqp install .
```

## Usage

```bash
# Install teez CLI (ReqPack release index — not this catalog)
rqp install rqp https://github.com/Coditary/teez-cli/releases/download/v0.1.1/teez-0.1.1-linux-x86_64.rqp

# Search optional runner plugins
rqp search teez vitest

# Install vitest runner plugin
rqp install teez vitest

# List installed catalog packages
rqp list teez
```

## Local registry (development)

Point `default-package-repositories.json` at a local `packages.json` or set a `file://` URL while developing the registry under `teez/registry/`.
