# dpkg Wrapper Design

## Goal

Implement ReqPack Lua plugin for Debian package management.
Plugin stays thin, but uses both `dpkg` and `apt` family tools so ReqPack API can expose install, remove, list, search, info, update, and outdated behavior.

## Command Model

- `apt-get install -y -- <pkg[=version]>` for normal installs
- `dpkg -i -- <file.deb>` for local artifact installs
- `dpkg -r -- <pkg>` for removals
- `apt-get install --only-upgrade -y -- <pkg>` for updates
- `dpkg-query -W ...` for installed-state checks and listing
- `apt-cache search` for search
- `apt-cache policy` and `apt-cache show` for package info and resolution
- `apt list --upgradable` for outdated packages

## API Mapping

- `getMissingPackages()` checks installed state with `dpkg-query`
- install actions emit `installed` then transaction `success`
- remove emits `deleted`
- update emits `updated`
- list/search/info/outdated return parsed package info tables and emit matching query events
- `resolvePackage()` returns exact installed or candidate version when available
- `getSecurityMetadata()` declares Debian ecosystem metadata for audit and SBOM integration

## Data Shape

Returned package records prefer reliable fields only:

- `name`, `packageId`, `version`, `latestVersion`
- `installed`, `status`, `architecture`
- `summary`, `description`, `homepage`, `section`
- `dependencies`, `optionalDependencies`, `provides`, `conflicts`, `replaces`
- `packageType = "deb"`, `type = "package"`

## Error Handling

- Mutating commands fail fast with `context.tx.failed(...)` and return `false`
- Query commands return empty arrays or empty tables on lookup failure
- `info()` emits `unavailable` when neither installed nor repository metadata exists

## Test Plan

Update hermetic `.reqpack-test/core` cases to fake:

- binary checks from `init()`
- apt and dpkg command strings for each action
- parsed outputs for list, search, info, and outdated

Validation target: `rqp test-plugin --plugin . --preset core`
