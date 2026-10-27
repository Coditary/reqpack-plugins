# rqp-plugin-huggingface

ReqPack Lua plugin for Hugging Face Hub downloads.

Plugin wraps Hugging Face CLI and downloads models, datasets, and spaces.
Bundle declares `nix:huggingface-hub` in `reqpack.lua`, so ReqPack can provision CLI dependency through existing `nix` plugin.

On `install` and `update`, plugin adopts downloaded snapshot files into local Unified AI Cache at `~/.local/share/aicache`.
It writes blob content under `blobs/sha256`, artifact metadata under `artifacts/...`, and query views under `views/...`.
Installed-state queries prefer this local cache first, then fall back to Hugging Face cache and CLI lookups.

## Package Syntax

- `owner/repo` for models
- `dataset:owner/repo` for datasets
- `space:owner/repo` for spaces
- append `//path/in/repo` to target one file or subfolder
- append `@revision` to request a branch, tag, or commit

Examples:

```bash
rqp install huggingface gpt2
rqp install huggingface dataset:HuggingFaceFW/fineweb
rqp install huggingface space:HuggingFaceH4/zephyr-chat
rqp install huggingface gpt2//config.json
rqp install huggingface dataset:HuggingFaceFW/fineweb@main//README.md
```

## Supported ReqPack Paths

- `install`
- `installLocal`
- `remove`
- `update`
- `list`
- `search`
- `info`
- `outdated`
- `resolvePackage`

## Cache Behavior

- `install` and `update` run visible `hf download ...` commands, then adopt resulting files into AICache
- adoption uses hardlinks first and falls back to `cp` when links are unavailable
- plugin writes `views/by-source/huggingface/<repo-type>/<repo-id>/current.json` so `list` and `info` can resolve from AICache without calling Hugging Face
- `remove` cleans artifact metadata, derived views, current pointer, and unreferenced adopted blobs
- original Hugging Face cache under `~/.cache/huggingface` stays unmanaged; AICache stores adopted copies/links only

## Testing

Run hermetic plugin tests from plugin root:

```bash
rqp test-plugin --plugin ./run.lua --preset core
```

## Notes

- plugin prefers modern `hf` binary and falls back to `huggingface-cli`
- downloads use visible Hugging Face CLI flows; targets remain resumable
- `list` and `info` prefer local AICache entries and fall back to Hugging Face CLI/cache when local cache is empty
- `outdated` still compares local cache refs against remote metadata via Hugging Face CLI
