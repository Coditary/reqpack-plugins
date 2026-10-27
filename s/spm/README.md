# reqpack-plugin-spm

ReqPack wrapper plugin for Skill Package Manager (`spm`).

Plugin manages project-installed AI skills through real `spm` CLI.

## Scope

- installs registry skills with `spm install`
- removes skills with `spm uninstall`
- updates project skills with `spm update`
- lists project-installed skills with `spm list --json`
- searches registry skills with `spm search --json`
- shows skill metadata with `spm info --json`
- derives outdated skills by comparing project lockfile versions against registry info

## Runtime And Cache Paths

- global shared store: `~/.spm/skills`
- global shared cache: `~/.spm/cache`
- project manifest: `skills.json`
- project lockfile: `skills-lock.json`
- linked agents: `~/.agents/skills`

## Package Forms

- `@scope/name`
- `@scope/name@version`
- local path only through `installLocal()`

Search flags supported through ReqPack request flags:

- `limit=<int>`
- `sort=<value>`
- `category=<slug>`
- `trust-tier=<value>`

## Notes

- wrapper follows current `spm` CLI surface where `install` also has alias `add`
- `list()` only reports project-bound installed skills, matching upstream behavior
- `installLocal()` requires observable installed state; otherwise plugin fails honestly
- `outdated()` is synthesized because current `spm` CLI has no dedicated outdated command

## Running Tests

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
