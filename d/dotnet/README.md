# dotnet

ReqPack Lua wrapper for `dotnet` workflows used by Q#.

Supports:

- `tool:<package>` via `dotnet tool`
- `template:<package>` via `dotnet new`
- `package:<package>` via `dotnet package`

Default package form without prefix: `tool:<package>`.

Shared workspace/cache paths:

- `.reqpack-data/dotnet/workspace/`
- `.reqpack-data/dotnet/workspace/dotnet-home/`
- `.reqpack-data/dotnet/workspace/nuget-packages/`
- `.reqpack-data/dotnet/workspace/tool-path/`
- `.reqpack-data/dotnet/workspace/tool-local/`
- `.reqpack-data/dotnet/workspace/qsharp-host/`

Supported actions:

- install
- installLocal
- remove
- update
- list
- outdated
- search
- info

Important v1 limits:

- bulk outdated for `tool:` not reliably supported by CLI, returns empty list
- local install only supports template `.nupkg` via `dotnet new install <path>`
- `package:` mutations without `project=` use shared host project under plugin workspace

Example:

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
