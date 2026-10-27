# rqp-plugin-wuji

ReqPack package manager plugin for **Wuji** — installs external driver plugins and catalog packages.

## Usage

```bash
# Install a driver plugin (downloads source, ensures reqpack.lua deps, builds binary)
rqp install wuji llama
rqp install wuji ffmpeg vllm

# Search the catalog
rqp search wuji llama

# Install the CLI via the wuji catalog entry (requires published .rqp release)
rqp install wuji wuji-ai
```

Drivers are installed under `~/.local/share/wuji/drivers/<id>/`.

The **wuji-ai** CLI can also be installed directly:

```bash
rqp install wuji-ai
```

## Layout

```
run.lua
metadata.json
reqpack.lua
default-package-repositories.json
scripts/
```

See the [ReqPack Wiki](https://github.com/Coditary/ReqPack/wiki/Extending-ReqPack) for plugin authoring details.
