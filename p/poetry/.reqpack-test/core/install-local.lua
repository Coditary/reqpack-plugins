return {
  name = "poetry install local editable dependency",
  request = {
    action = "install",
    system = "poetry",
    flags = { "dir=./fixtures/project", "editable" },
    localPath = "./fixtures/libs/demo-lib",
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
      match = "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project add --no-interaction --editable ./fixtures/libs/demo-lib",
      exitCode = 0,
      stdout = "installed local package\n",
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "POETRY_CACHE_DIR='/home/test/.cache/reqpack/poetry/cache' POETRY_CONFIG_DIR='/home/test/.cache/reqpack/poetry/config' POETRY_DATA_DIR='/home/test/.cache/reqpack/poetry/data' poetry -C ./fixtures/project add --no-interaction --editable ./fixtures/libs/demo-lib"
    },
    events = { "installed", "success" },
  },
}
