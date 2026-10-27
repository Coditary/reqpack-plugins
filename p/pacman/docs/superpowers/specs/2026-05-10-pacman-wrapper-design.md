# Pacman Wrapper Design

## Goal

Turn template repository into ReqPack Lua wrapper plugin for native Arch Linux `pacman`.
Plugin targets official pacman repositories and local pacman package files only.
No AUR support. No helper tools like `yay` or `paru`.

## Scope

In scope:

- plugin metadata and bundle manifest updates
- `run.lua` implementation for required ReqPack methods
- optional `outdated()` and `getSecurityMetadata()`
- support for local package files handled by pacman
- hermetic `.reqpack-test/core/` cases updated to match pacman behavior
- README updated from template wording to pacman plugin wording

Out of scope:

- AUR package resolution or installation
- pacman repository configuration management
- GPG keyring/bootstrap handling
- privilege escalation management beyond invoking `pacman` directly
- advanced dependency or conflict resolution beyond what pacman already does

## Design Choice

Use thin shell-wrapper design.
`run.lua` remains single main file with small helper functions for:

- shell quoting
- command execution result handling
- package name extraction
- conservative parsing of pacman output

This keeps plugin aligned with ReqPack guidance: thin wrapper, real package-manager behavior delegated to native pacman.

## Runtime Behavior

### Initialization

- `plugin.init()` checks `command -v pacman >/dev/null 2>&1`
- plugin assumes pacman already installed natively on host

### Metadata

- plugin id becomes `pacman`
- plugin name presented as `Pacman`
- categories reflect Linux system package manager behavior
- `plugin.fileExtensions` includes pacman local package extensions such as `.pkg.tar`, `.pkg.tar.zst`, `.pkg.tar.xz`, `.pkg.tar.gz`, `.pkg.tar.bz2`, `.pkg.tar.lz4`, `.pkg.tar.lrz`, `.pkg.tar.lzo`, `.pkg.tar.Z`

### Planning: `getMissingPackages(packages)`

Function improves ReqPack planning instead of lazily returning all packages.

Rules:

- `install`: package stays only if `pacman -Q <name>` reports not installed
- `remove`: package stays only if `pacman -Q <name>` reports installed
- `update`: package stays only if package appears in `pacman -Qu` output
- unknown or empty package names are ignored

This method may run multiple small pacman queries because correctness and thinness matter more than micro-optimization in wrapper layer.

### Install

- command shape: `pacman -S --needed --noconfirm <packages>`
- package versions from ReqPack requests are ignored for command construction because pacman native install command is name-based for repository installs
- on success emit `context.events.installed(packages)` and `context.tx.success()`
- on failure emit `context.tx.failed("pacman install failed")` and return `false`

### Local Install

- command shape: `pacman -U --noconfirm <path>`
- success emits installed event payload with path and `localTarget = true`
- failure returns `false`

### Remove

- command shape: `pacman -R --noconfirm <packages>`
- no recursive cleanup flags added by default to avoid surprising removal behavior
- success emits deleted event

### Update

- if package list provided, command shape: `pacman -S --noconfirm <packages>`
- if ReqPack later calls update with empty package list, plugin returns `true` without command to avoid guessing full-system upgrade semantics
- success emits updated event

### List

- command shape: `pacman -Q`
- parse lines as `<name> <version>`
- return package info array with at least `name`, `version`, `installed = true`, `status = "installed"`, `packageType = "package"`
- emit listed event with result array

### Search

- command shape: `pacman -Ss <prompt>`
- parse block pairs conservatively:
  - header line usually `<repo>/<name> <version>`
  - next indented line used as summary when present
- return package info array with `name`, `version`, `repository`, `summary`, `packageType = "package"`
- empty prompt returns empty list

### Info

- first try `pacman -Si <name>` for repository metadata
- fallback to `pacman -Qi <name>` for installed-only package metadata
- parse `Key : Value` lines conservatively
- return single package info table with available fields such as `name`, `version`, `description`, `architecture`, `license`, `repository`, `homepage`, `depends`, `optionalDependencies`
- unknown package returns empty table rather than failing whole plugin action

### Outdated

- command shape: `pacman -Qu`
- parse lines as `<name> <current> -> <latest>`
- return package info array with `name`, `version`, `latestVersion`, `installed = true`, `status = "outdated"`
- emit outdated event

## Parsing Strategy

Parsing stays conservative and line-oriented.

- do not depend on colorized or localized formatting beyond standard pacman plain output assumptions used in tests
- ignore lines that do not match expected formats
- prefer partially filled package info records over brittle full parsing

Helper functions should normalize whitespace and only extract fields that can be identified reliably.

## Error Handling

- Action methods use `context.tx.begin_step(...)` before real work when meaningful
- Command failures mark transaction failed and return `false`
- Read-style methods (`list`, `search`, `info`, `outdated`) return empty results when pacman reports missing package or no matches, unless command failure clearly indicates execution problem
- Empty package arrays short-circuit successfully for mutating operations

## Security Metadata

`plugin.getSecurityMetadata()` should describe pacman wrapper as:

- `role = "package-manager"`
- `capabilities = { "exec" }`
- `ecosystemScopes = { "alpm", "arch" }`
- `privilegeLevel = "sudo"`
- `osvEcosystem = "Linux"`
- `purlType = "alpm"`
- no version comparator profile declared unless ReqPack runtime later documents pacman-specific support

No network scopes declared because wrapper itself only executes pacman; pacman network activity is indirect.

## Test Plan

Update `.reqpack-test/core/` to hermetic pacman commands and outputs:

- `install.lua`: expects `pacman -S --needed --noconfirm ...`
- `install-local.lua`: expects `pacman -U --noconfirm ...`
- `remove.lua`: expects `pacman -R --noconfirm ...`
- `update.lua`: expects `pacman -S --noconfirm ...`
- `list.lua`: fake `pacman -Q` output parsed into results
- `search.lua`: fake `pacman -Ss` output parsed into results
- `info.lua`: fake `pacman -Si` output parsed into one record
- `outdated.lua`: fake `pacman -Qu` output parsed into results

Add fake command for `plugin.init()` only if hermetic runner executes lifecycle init during tests.
If tests prove that `init()` command must be mocked, each case will include matching `command -v pacman >/dev/null 2>&1` fake rule.

## Implementation Notes

- Keep comments short and only where parsing is non-obvious
- Avoid introducing extra files or abstraction layers unless implementation reveals real need
- Preserve required hook stub files as `return true`
- README should describe pacman plugin usage and test command from plugin root

## Success Criteria

Implementation is considered complete when:

- bundle metadata no longer contains template placeholders
- all required plugin methods perform pacman-specific behavior
- hermetic core tests match pacman command and parsing behavior
- plugin remains thin and understandable in one main file
