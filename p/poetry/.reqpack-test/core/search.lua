return {
  name = "poetry search shared query project",
  request = {
    action = "search",
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
      match = "POETRY_CACHE_DIR='./fixtures/cache-root/cache' POETRY_CONFIG_DIR='./fixtures/cache-root/config' POETRY_DATA_DIR='./fixtures/cache-root/data' poetry -C ./fixtures/cache-root/query-project search requests",
      exitCode = 0,
      stdout = "requests                  Python HTTP for Humans.\nrequests-mock             Mock out responses from requests.\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "POETRY_CACHE_DIR='./fixtures/cache-root/cache' POETRY_CONFIG_DIR='./fixtures/cache-root/config' POETRY_DATA_DIR='./fixtures/cache-root/data' poetry -C ./fixtures/cache-root/query-project search requests"
    },
    resultCount = 2,
    resultName = "requests",
    events = { "searched" },
  },
}
