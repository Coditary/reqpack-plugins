# red_cli API

## Supported request forms

- `name = "/abs/path/to/project"`
- `name = "/abs/path/to/red.config.json"`
- `name = "TrackedProjectName"`
- `localPath = "/abs/path/to/project"`
- `localPath = "/abs/path/to/red.config.json"`

## Flags

- `data-root=/abs/path`: override shared plugin state root
- `cache-root=/abs/path`: alias of `data-root`
- `bundle`: run `red-cli install --bundle`

## Behavior summary

- `install()` runs `red-cli install` in each resolved project root and tracks it on success
- `installLocal()` supports local project directories and direct `red.config.json` paths
- `remove()` deletes derived install targets from game directory and untracks project roots
- `update()` reruns install for requested or all tracked projects
- `list()` returns tracked projects only
- `search()` searches tracked projects only
- `info()` resolves one tracked or path-based project and returns config metadata
- `outdated()` returns empty list

## Important paths

- tracked projects: `~/.cache/reqpack/red_cli/tracked-projects.txt`

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
