# Carbon Plugin API

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `info`
- `outdated` (empty by design)
- `search` (empty by design)

## Package forms

- install: Docker image ref like `registry.example.com/team/app:1.2.3`
- remove/info(listed): installed Carbon package name like `app-name`

## Supported flags

- `namespace=<ns>`
- `minikube`
- `default-prune-white-list`
- `var=KEY=VALUE`
- `var-file=/path/file`
- `patch=<yaml-or-json>`
- `patch-file=/path/file`
- `data-root=/path`
- `cache-root=/path`
- `config-root=/path`

## Runtime/cache paths

- data: `~/.local/share/reqpack/carbon`
- cache: `~/.cache/reqpack/carbon`
- config: `~/.config/reqpack/carbon`
- Carbon home var file: `~/.config/reqpack/carbon/home/.carbon/carbon.vars`

## Limitations

- no remote package search in Carbon CLI
- no reliable outdated detection in Carbon CLI
- no local artifact install path in Carbon CLI
- update reuses installed package source image and request flags only

## Test

```bash
rqp test-plugin --plugin ./run.lua --preset core
```
