return {
  name = "poetry info via shared query project",
  request = {
    action = "info",
    system = "poetry",
    prompt = "requests",
    flags = { "cache-root=./fixtures/cache-root" },
  },
  fixtureDirs = {
    "./fixtures/cache-root",
    "./fixtures/cache-root/cache",
    "./fixtures/cache-root/config",
    "./fixtures/cache-root/data",
    "./fixtures/cache-root/query-project",
  },
  fixtureFiles = {
    {
      path = "./fixtures/cache-root/query-project/pyproject.toml",
      content = [[
[tool.poetry]
name = "reqpack-poetry-query"
version = "0.0.0"
description = "ReqPack Poetry query cache"
authors = []
package-mode = false

[tool.poetry.dependencies]
python = "*"
]],
    },
    {
      path = "./fixtures/cache-root/query-project/poetry.lock",
      content = [=[
[[package]]
name = "requests"
version = "2.32.3"
description = "Python HTTP for Humans."
optional = false
python-versions = ">=3.8"
groups = ["main"]
homepage = "https://requests.readthedocs.io"
license = "Apache-2.0"
files = [
    {file = "requests-2.32.3-py3-none-any.whl", hash = "sha256:abc123"},
]

[package.dependencies]
certifi = ">=2017.4.17"
charset-normalizer = ">=2,<4"

[package.source]
type = "legacy"
url = "https://pypi.org/simple"
]=],
    },
  },
  fakeExec = {
    {
      match = "command -v 'poetry' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "POETRY_CACHE_DIR='./fixtures/cache-root/cache' POETRY_CONFIG_DIR='./fixtures/cache-root/config' POETRY_DATA_DIR='./fixtures/cache-root/data' poetry -C ./fixtures/cache-root/query-project add --no-interaction --lock requests",
      exitCode = 0,
      stdout = "resolved requests\n",
      stderr = "",
      success = true,
    },
    {
      match = "POETRY_CACHE_DIR='./fixtures/cache-root/cache' POETRY_CONFIG_DIR='./fixtures/cache-root/config' POETRY_DATA_DIR='./fixtures/cache-root/data' poetry -C ./fixtures/cache-root/query-project show --format json requests",
      exitCode = 0,
      stdout = [[{"name":"requests","version":"2.32.3","description":"Python HTTP for Humans.","dependencies":{"certifi":">=2017.4.17","charset-normalizer":">=2,<4"},"required_by":{}}]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "POETRY_CACHE_DIR='./fixtures/cache-root/cache' POETRY_CONFIG_DIR='./fixtures/cache-root/config' POETRY_DATA_DIR='./fixtures/cache-root/data' poetry -C ./fixtures/cache-root/query-project add --no-interaction --lock requests",
      "POETRY_CACHE_DIR='./fixtures/cache-root/cache' POETRY_CONFIG_DIR='./fixtures/cache-root/config' POETRY_DATA_DIR='./fixtures/cache-root/data' poetry -C ./fixtures/cache-root/query-project show --format json requests"
    },
    resultCount = 1,
    resultName = "requests",
    resultVersion = "2.32.3",
    events = { "informed" },
  },
}
