# dotnet API

## Package forms

- `tool:Microsoft.Quantum.IQSharp`
- `template:Microsoft.Quantum.ProjectTemplates`
- `package:Microsoft.Quantum.Sdk`

No prefix means `tool:`.

## Common flags

- `cache-root=<path>`
- `source=<url>`
- `prerelease`

## Tool flags

- `scope=global|local|path`
- `tool-path=<path>`
- `tool-manifest=<path>`
- `create-manifest-if-needed`

## Package flags

- `project=<path>`
- `framework=<tfm>`
- `package-directory=<path>`
- `no-restore`

## Query notes

- `list()` returns installed items from all supported kinds
- `outdated()` returns template/package updates; tool updates are not exposed reliably by CLI
- `search()` searches tools and templates remotely; `package:` search uses `dotnet package list` only for installed/outdated, so remote package search is not part of v1
- `info()` prefers installed state, then remote lookup where CLI supports it

## Local install

- supported: template `.nupkg`
- unsupported: arbitrary local tool/package artifacts
