# MCPM ReqPack Plugin Spec

## Goal

Wrap the `mcpm` CLI from `mcpm.sh` as a ReqPack package-manager plugin for installing, removing, listing, updating, searching, and inspecting MCP servers. The plugin manages MCPM server entries, not the ReqPack plugin wrapper itself.

## Upstream Capability Map

- `mcpm search [query]`: discover MCP servers from the MCPM registry.
- `mcpm info SERVER_NAME`: inspect one registry server with install metadata.
- `mcpm install SERVER_NAME [--force] [--alias ALIAS]`: install a registry server into MCPM global config.
- `mcpm uninstall SERVER_NAME --force`: remove a server from MCPM global config and profile tags.
- `mcpm ls --verbose`: list installed servers from MCPM global config.
- `mcpm update [SERVER_NAME]`: update one or all installed servers.
- `mcpm update --check`: dry-run check for available updates.
- `mcpm new SERVER_NAME --type ...`: create custom non-registry stdio or remote servers.
- Profile, client, run, share, usage, doctor, and config commands exist, but are outside ReqPack package mutation semantics for v1.

## ReqPack Behavior

- `install(context, packages)` wraps `mcpm install`; package flags support `force` and `alias=<name>`.
- `installLocal(context, path)` wraps `mcpm new` for local/custom servers. The request can provide flags:
  - `name=<server>` is required.
  - `type=stdio` or `type=remote`, defaults to `stdio`.
  - `command=<command>` for stdio servers, defaults to the path argument.
  - `args=<args>`, `env=<KEY=value,...>`, `url=<url>`, `headers=<KEY=value,...>`, `force`.
- `remove(context, packages)` wraps `mcpm uninstall --force`.
- `update(context, packages)` wraps `mcpm update`; no packages means update all installed servers.
- `list(context)` wraps `mcpm ls --verbose` and returns installed MCP server records.
- `outdated(context)` wraps `mcpm update --check` and returns servers with newer source state when MCPM reports them.
- `search(context, prompt)` wraps `mcpm search [prompt]`; empty prompt lists registry entries.
- `info(context, name)` wraps `mcpm info`.
- `resolvePackage(context, package)` returns installed/remote info when available, otherwise a normalized MCP server record.

## Runtime And Cache Model

Every action runs MCPM in non-interactive JSON mode:

- `MCPM_NON_INTERACTIVE=true`
- `MCPM_FORCE=true`
- `MCPM_JSON_OUTPUT=true`
- `NO_COLOR=1`
- `LC_ALL=C LANG=C LANGUAGE=C`

The wrapper pins MCPM state under ReqPack-scoped roots:

- config: `~/.config/reqpack/mcpm/config`
- cache: `~/.cache/reqpack/mcpm/cache`
- data/state: `~/.local/share/reqpack/mcpm/data`

These are passed with `MCPM_CONFIG_DIR`, `XDG_CACHE_HOME`, and `XDG_DATA_HOME` so registry cache, global config, and installed server state share one predictable ReqPack-owned area. Tests can override roots with `config-root=`, `cache-root=`, and `data-root=` flags.

## Output Normalization

The plugin prefers JSON output. Because MCPM versions may return arrays or keyed objects, parsers accept both broad shapes and normalize records into ReqPack package items with:

- `name`
- `packageId`
- `version` or `latestVersion` when available
- `packageType = "mcp-server"`
- `type = "package"`
- `installed`
- `status`
- `summary`, `description`
- `extraFields` for source, profile/client assignment, command, url, aliases, registry metadata, and raw MCPM fields.

If query commands fail or output cannot be parsed, query paths degrade gracefully with warnings and empty results. Mutating commands fail clearly.

## Security Metadata

The plugin declares:

- role: `package-manager`
- capabilities: `exec`, `network`
- ecosystem scope: `mcpm`
- write scopes for ReqPack-owned `mcpm` config/cache/data directories
- privilege level: `user`
- package URL type: `generic`

## Test Plan

Hermetic core tests cover:

- registry install with alias/force flags
- local/custom stdio install via `mcpm new`
- uninstall
- update specific server
- list installed servers from JSON object output
- outdated from `mcpm update --check`
- search registry output
- info output

All fake exec command strings must match the wrapper's exact env prefix and quoting.
# MCPM ReqPack Plugin Spec

## Goal

Wrap the `mcpm` CLI from `mcpm.sh` as a ReqPack package-manager plugin for installing, removing, listing, updating, searching, and inspecting MCP servers. The plugin manages MCPM server entries, not the ReqPack plugin wrapper itself.

## Upstream Capability Map

- `mcpm search [query]`: discover MCP servers from the MCPM registry.
- `mcpm info SERVER_NAME`: inspect one registry server with install metadata.
- `mcpm install SERVER_NAME [--force] [--alias ALIAS]`: install a registry server into MCPM global config.
- `mcpm uninstall SERVER_NAME --force`: remove a server from MCPM global config and profile tags.
- `mcpm ls --verbose`: list installed servers from MCPM global config.
- `mcpm update [SERVER_NAME]`: update one or all installed servers.
- `mcpm update --check`: dry-run check for available updates.
- `mcpm new SERVER_NAME --type ...`: create custom non-registry stdio or remote servers.
- Profile, client, run, share, usage, doctor, and config commands exist, but are outside ReqPack package mutation semantics for v1.

## ReqPack Behavior

- `install(context, packages)` wraps `mcpm install`; package flags support `force` and `alias=<name>`.
- `installLocal(context, path)` wraps `mcpm new` for local/custom servers. The request can provide flags:
  - `name=<server>` is required.
  - `type=stdio` or `type=remote`, defaults to `stdio`.
  - `command=<command>` for stdio servers, defaults to the path argument.
  - `args=<args>`, `env=<KEY=value,...>`, `url=<url>`, `headers=<KEY=value,...>`, `force`.
- `remove(context, packages)` wraps `mcpm uninstall --force`.
- `update(context, packages)` wraps `mcpm update`; no packages means update all installed servers.
- `list(context)` wraps `mcpm ls --verbose` and returns installed MCP server records.
- `outdated(context)` wraps `mcpm update --check` and returns servers with newer source state when MCPM reports them.
- `search(context, prompt)` wraps `mcpm search [prompt]`; empty prompt lists registry entries.
- `info(context, name)` wraps `mcpm info`.
- `resolvePackage(context, package)` returns installed/remote info when available, otherwise a normalized MCP server record.

## Runtime And Cache Model

Every action runs MCPM in non-interactive JSON mode:

- `MCPM_NON_INTERACTIVE=true`
- `MCPM_FORCE=true`
- `MCPM_JSON_OUTPUT=true`
- `NO_COLOR=1`
- `LC_ALL=C LANG=C LANGUAGE=C`

The wrapper pins MCPM state under ReqPack-scoped roots:

- config: `~/.config/reqpack/mcpm/config`
- cache: `~/.cache/reqpack/mcpm/cache`
- data/state: `~/.local/share/reqpack/mcpm/data`

These are passed with `MCPM_CONFIG_DIR`, `XDG_CACHE_HOME`, and `XDG_DATA_HOME` so registry cache, global config, and installed server state share one predictable ReqPack-owned area. Tests can override roots with `config-root=`, `cache-root=`, and `data-root=` flags.

## Output Normalization

The plugin prefers JSON output. Because MCPM versions may return arrays or keyed objects, parsers accept both broad shapes and normalize records into ReqPack package items with:

- `name`
- `packageId`
- `version` or `latestVersion` when available
- `packageType = "mcp-server"`
- `type = "package"`
- `installed`
- `status`
- `summary`, `description`
- `extraFields` for source, profile/client assignment, command, url, aliases, registry metadata, and raw MCPM fields.

If query commands fail or output cannot be parsed, query paths degrade gracefully with warnings and empty results. Mutating commands fail clearly.

## Security Metadata

The plugin declares:

- role: `package-manager`
- capabilities: `exec`, `network`
- ecosystem scope: `mcpm`
- write scopes for ReqPack-owned `mcpm` config/cache/data directories
- privilege level: `user`
- package URL type: `generic`

## Test Plan

Hermetic core tests cover:

- registry install with alias/force flags
- local/custom stdio install via `mcpm new`
- uninstall
- update specific server
- list installed servers from JSON object output
- outdated from `mcpm update --check`
- search registry output
- info output

All fake exec command strings must match the wrapper's exact env prefix and quoting.
